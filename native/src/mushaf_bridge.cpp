#include <jni.h>
#include <android/log.h>
#include <string>
#include <vector>
#include <iostream>
#include <ft2build.h>
#include FT_FREETYPE_H
#include FT_OUTLINE_H
#include <hb.h>

#define LOG_TAG "MushafRenderer"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)

// --- Structs shared with Dart ---

struct ShapedGlyph {
    uint32_t glyph_id;
    int32_t x_offset;
    int32_t y_offset;
    int32_t x_advance;
    int32_t y_advance;
    int32_t cluster;
};

struct ShapedGlyphData {
    ShapedGlyph* glyphs;
    int32_t count;
};

struct GlyphPathData {
    float* points; 
    int32_t num_points;
    int32_t path_type;
};

// --- Globals ---
static FT_Library ft_library = nullptr;
static FT_Face ft_face = nullptr;
static hb_font_t* hb_font = nullptr;
static hb_face_t* hb_face = nullptr;
static hb_blob_t* hb_blob = nullptr;

// --- HarfBuzz Callbacks ---

static hb_bool_t get_nominal_glyph(hb_font_t* font, void* font_data, hb_codepoint_t unicode, hb_codepoint_t* glyph, void* user_data) {
    FT_Face face = (FT_Face)font_data; // Correct: Use font_data
    *glyph = FT_Get_Char_Index(face, unicode);
    return *glyph != 0;
}

static hb_position_t get_glyph_h_advance(hb_font_t* font, void* font_data, hb_codepoint_t glyph, void* user_data) {
    FT_Face face = (FT_Face)font_data; // Correct: Use font_data
    int load_flags = FT_LOAD_DEFAULT | FT_LOAD_NO_HINTING;
    if (FT_Load_Glyph(face, glyph, load_flags) != 0) return 0;
    // HarfBuzz uses 26.6 fixed point
    return face->glyph->advance.x; 
}

static hb_font_funcs_t* get_hb_font_funcs() {
    static hb_font_funcs_t* funcs = nullptr;
    if (!funcs) {
        funcs = hb_font_funcs_create();
        hb_font_funcs_set_nominal_glyph_func(funcs, get_nominal_glyph, nullptr, nullptr);
        hb_font_funcs_set_glyph_h_advance_func(funcs, get_glyph_h_advance, nullptr, nullptr);
        hb_font_funcs_make_immutable(funcs);
    }
    return funcs;
}

// --- FreeType Outline Decomposer ---

struct PathContext {
    std::vector<float> points;
};

int move_to(const FT_Vector* to, void* user) {
    PathContext* ctx = (PathContext*)user;
    ctx->points.push_back(0.0f);
    ctx->points.push_back(to->x / 64.0f);
    ctx->points.push_back(-to->y / 64.0f);
    return 0;
}

int line_to(const FT_Vector* to, void* user) {
    PathContext* ctx = (PathContext*)user;
    ctx->points.push_back(1.0f);
    ctx->points.push_back(to->x / 64.0f);
    ctx->points.push_back(-to->y / 64.0f);
    return 0;
}

int conic_to(const FT_Vector* control, const FT_Vector* to, void* user) {
    PathContext* ctx = (PathContext*)user;
    ctx->points.push_back(2.0f);
    ctx->points.push_back(control->x / 64.0f);
    ctx->points.push_back(-control->y / 64.0f);
    ctx->points.push_back(to->x / 64.0f);
    ctx->points.push_back(-to->y / 64.0f);
    return 0;
}

int cubic_to(const FT_Vector* control1, const FT_Vector* control2, const FT_Vector* to, void* user) {
    PathContext* ctx = (PathContext*)user;
    ctx->points.push_back(3.0f);
    ctx->points.push_back(control1->x / 64.0f);
    ctx->points.push_back(-control1->y / 64.0f);
    ctx->points.push_back(control2->x / 64.0f);
    ctx->points.push_back(-control2->y / 64.0f);
    ctx->points.push_back(to->x / 64.0f);
    ctx->points.push_back(-to->y / 64.0f);
    return 0;
}

// --- Exported Functions ---

extern "C" __attribute__((visibility("default")))
bool init_font_renderer(const uint8_t* font_data, int32_t font_data_size) {
    if (ft_library != nullptr) {
        LOGD("Font renderer already initialized");
    } else {
        if (FT_Init_FreeType(&ft_library)) {
            LOGE("Could not init FreeType library");
            return false;
        }
    }

    // Cleanup old resources
    if (hb_font) hb_font_destroy(hb_font);
    if (hb_face) hb_face_destroy(hb_face);
    if (hb_blob) hb_blob_destroy(hb_blob);
    if (ft_face) FT_Done_Face(ft_face);
    
    hb_font = nullptr;
    hb_face = nullptr;
    hb_blob = nullptr;
    ft_face = nullptr;

    // 1. Initialize FreeType Face
    if (FT_New_Memory_Face(ft_library, font_data, font_data_size, 0, &ft_face)) {
        LOGE("Could not load font from memory");
        return false;
    }

    FT_Set_Pixel_Sizes(ft_face, 0, 100);

    // 2. Create HarfBuzz Blob & Face
    // We use READONLY mode because the data is owned by Dart/Flutter side
    hb_blob = hb_blob_create((const char*)font_data, font_data_size, HB_MEMORY_MODE_READONLY, nullptr, nullptr);
    if (!hb_blob) {
        LOGE("Failed to create HarfBuzz blob");
        return false;
    }

    hb_face = hb_face_create(hb_blob, 0);
    if (!hb_face) {
        LOGE("Failed to create HarfBuzz face");
        return false;
    }

    // 3. Create HarfBuzz Font and hook it up to FreeType
    hb_font = hb_font_create(hb_face);
    
    // Critical: Pass 'ft_face' as user_data so our callbacks can use it
    hb_font_set_funcs(hb_font, get_hb_font_funcs(), ft_face, nullptr);
    
    hb_font_set_scale(hb_font, 100 * 64, 100 * 64); 

    LOGD("Font renderer initialized successfully with font");
    return true;
}

extern "C" __attribute__((visibility("default")))
ShapedGlyphData shape_text_ffi(const char* text_utf8) {
    if (hb_font == nullptr) {
        LOGE("Font not initialized");
        return {nullptr, 0};
    }

    hb_buffer_t* buffer = hb_buffer_create();
    hb_buffer_add_utf8(buffer, text_utf8, -1, 0, -1);
    
    hb_buffer_set_direction(buffer, HB_DIRECTION_RTL);
    hb_buffer_set_script(buffer, HB_SCRIPT_ARABIC);
    hb_buffer_set_language(buffer, hb_language_from_string("ar", -1));

    hb_shape(hb_font, buffer, nullptr, 0);

    unsigned int glyph_count;
    hb_glyph_info_t* glyph_info = hb_buffer_get_glyph_infos(buffer, &glyph_count);
    hb_glyph_position_t* glyph_pos = hb_buffer_get_glyph_positions(buffer, &glyph_count);

    ShapedGlyph* result_glyphs = new ShapedGlyph[glyph_count];
    
    for (unsigned int i = 0; i < glyph_count; i++) {
        result_glyphs[i].glyph_id = glyph_info[i].codepoint;
        result_glyphs[i].cluster = glyph_info[i].cluster;
        result_glyphs[i].x_offset = glyph_pos[i].x_offset;
        result_glyphs[i].y_offset = glyph_pos[i].y_offset;
        result_glyphs[i].x_advance = glyph_pos[i].x_advance;
        result_glyphs[i].y_advance = glyph_pos[i].y_advance;

        if (i < 5) {
             LOGD("Native Shaped Glyph %d: ID=%u", i, result_glyphs[i].glyph_id);
        }
    }

    hb_buffer_destroy(buffer);

    return {result_glyphs, (int32_t)glyph_count};
}

extern "C" __attribute__((visibility("default")))
void free_shaped_glyph_data(ShapedGlyphData data) {
    delete[] data.glyphs;
}

extern "C" __attribute__((visibility("default")))
GlyphPathData get_glyph_path_ffi(uint32_t glyph_id) {
    if (ft_face == nullptr) {
        LOGE("Face not initialized for glyph %d", glyph_id);
        return {nullptr, 0, 0};
    }

    // Load glyph with NO_BITMAP to get outline
    int error = FT_Load_Glyph(ft_face, glyph_id, FT_LOAD_NO_BITMAP);
    if (error) {
        LOGE("Failed to load glyph %d, error: %d", glyph_id, error);
        return {nullptr, 0, 0};
    }

    FT_Outline_Funcs callbacks = { move_to, line_to, conic_to, cubic_to, 0, 0 };
    PathContext context;
    
    if (ft_face->glyph->format == FT_GLYPH_FORMAT_OUTLINE) {
        FT_Outline_Decompose(&ft_face->glyph->outline, &callbacks, &context);
        LOGD("Glyph %d: Decomposed into %zu floats", glyph_id, context.points.size());
    } else {
        LOGE("Glyph %d format is NOT outline (format: %c%c%c%c)", glyph_id, 
             (ft_face->glyph->format >> 24) & 0xFF,
             (ft_face->glyph->format >> 16) & 0xFF,
             (ft_face->glyph->format >> 8) & 0xFF,
             (ft_face->glyph->format) & 0xFF);
    }

    // If points are empty, this is a "space" or invalid glyph
    if (context.points.empty()) {
        // LOGD("Glyph %d has no points (space?)", glyph_id);
        return {nullptr, 0, 0};
    }

    float* raw_points = new float[context.points.size()];
    std::copy(context.points.begin(), context.points.end(), raw_points);

    return {raw_points, (int32_t)context.points.size(), 0};
}

extern "C" __attribute__((visibility("default")))
void free_glyph_path_data(GlyphPathData data) {
    delete[] data.points;
}

extern "C" __attribute__((visibility("default")))
void dispose_font_renderer() {
    if (hb_font) hb_font_destroy(hb_font);
    if (hb_face) hb_face_destroy(hb_face);
    if (hb_blob) hb_blob_destroy(hb_blob);
    if (ft_face) FT_Done_Face(ft_face);
    if (ft_library) FT_Done_FreeType(ft_library);
    
    hb_font = nullptr;
    hb_face = nullptr;
    hb_blob = nullptr;
    ft_face = nullptr;
    ft_library = nullptr;
    LOGD("Font renderer disposed");
}

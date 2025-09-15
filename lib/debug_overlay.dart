import 'package:flutter/material.dart';
import 'models/ayah_marker.dart';

class DebugOverlay extends StatefulWidget {
  final List<AyahMarker> markers;
  final double sourceWidth;
  final double sourceHeight;
  final BoxConstraints constraints;
  final Function(double scale, double offsetX, double offsetY) onTransformChanged;

  const DebugOverlay({
    super.key,
    required this.markers,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.constraints,
    required this.onTransformChanged,
  });

  @override
  State<DebugOverlay> createState() => _DebugOverlayState();
}

class _DebugOverlayState extends State<DebugOverlay> {
  double _debugScale = 1.0;
  double _debugOffsetX = 0.0;
  double _debugOffsetY = 0.0;
  bool _showDebugPanel = true;
  bool _showBoundingBoxes = true;

  @override
  void initState() {
    super.initState();
    // Calculate initial SVG scale as baseline
    final double scaleX = widget.constraints.maxWidth / widget.sourceWidth;
    final double scaleY = widget.constraints.maxHeight / widget.sourceHeight;
    final double svgScale = scaleX < scaleY ? scaleX : scaleY;
    
    _debugScale = svgScale;
    
    // Calculate initial SVG offset
    final double renderedWidth = widget.sourceWidth * svgScale;
    final double renderedHeight = widget.sourceHeight * svgScale;
    _debugOffsetX = (widget.constraints.maxWidth - renderedWidth) / 2;
    _debugOffsetY = (widget.constraints.maxHeight - renderedHeight) / 2;
    
    // Defer the callback until after the build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyChange();
    });
  }

  void _notifyChange() {
    widget.onTransformChanged(_debugScale, _debugOffsetX, _debugOffsetY);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Bounding boxes visualization
        if (_showBoundingBoxes) ..._buildBoundingBoxes(),
        
        // Debug control panel
        if (_showDebugPanel) _buildDebugPanel(),
        
        // Toggle button
        Positioned(
          top: 50,
          right: 20,
          child: FloatingActionButton.small(
            onPressed: () {
              setState(() {
                _showDebugPanel = !_showDebugPanel;
              });
            },
            backgroundColor: Colors.red.withValues(alpha: 0.8),
            child: Icon(_showDebugPanel ? Icons.close : Icons.settings),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildBoundingBoxes() {
    final List<Widget> boxes = [];
    
    for (int i = 0; i < widget.markers.length; i++) {
      final marker = widget.markers[i];
      final color = _getDebugColor(i);
      
      if (marker.bboxes.isNotEmpty) {
        // Multi-bbox markers
        for (int j = 0; j < marker.bboxes.length; j++) {
          final bbox = marker.bboxes[j];
          boxes.add(_buildBoundingBox(bbox, color, '${marker.surah}:${marker.ayah}-$j'));
        }
      } else {
        // Point markers
        boxes.add(_buildPointMarker(marker, color, '${marker.surah}:${marker.ayah}'));
      }
    }
    
    return boxes;
  }

  Widget _buildBoundingBox(BoundingBox bbox, Color color, String label) {
    final double left = (bbox.xMin * _debugScale) + _debugOffsetX;
    final double top = (bbox.yMin * _debugScale) + _debugOffsetY;
    final double width = bbox.width * _debugScale;
    final double height = bbox.height * _debugScale;

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 2),
          color: color.withValues(alpha: 0.1),
        ),
        child: width > 60 && height > 20 ? Center(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ) : null,
      ),
    );
  }

  Widget _buildPointMarker(AyahMarker marker, Color color, String label) {
    const double size = 20.0;
    final double x = (marker.x * _debugScale) + _debugOffsetX;
    final double y = (marker.y * _debugScale) + _debugOffsetY;

    return Positioned(
      left: x - (size / 2),
      top: y - (size / 2),
      width: size,
      height: size,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: Center(
          child: Text(
            label.split(':')[1], // Show just ayah number
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDebugPanel() {
    return Positioned(
      top: 100,
      right: 20,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Debug Controls',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            // Scale controls
            Text('Scale: ${_debugScale.toStringAsFixed(3)}', style: const TextStyle(color: Colors.white)),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => _adjustScale(-0.001),
                  child: const Text('-0.001'),
                ),
                const SizedBox(width: 4),
                ElevatedButton(
                  onPressed: () => _adjustScale(-0.01),
                  child: const Text('-0.01'),
                ),
                const SizedBox(width: 4),
                ElevatedButton(
                  onPressed: () => _adjustScale(0.001),
                  child: const Text('+0.001'),
                ),
                const SizedBox(width: 4),
                ElevatedButton(
                  onPressed: () => _adjustScale(0.01),
                  child: const Text('+0.01'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Offset X controls
            Text('Offset X: ${_debugOffsetX.toStringAsFixed(1)}', style: const TextStyle(color: Colors.white)),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => _adjustOffsetX(-10),
                  child: const Text('-10'),
                ),
                const SizedBox(width: 4),
                ElevatedButton(
                  onPressed: () => _adjustOffsetX(-1),
                  child: const Text('-1'),
                ),
                const SizedBox(width: 4),
                ElevatedButton(
                  onPressed: () => _adjustOffsetX(1),
                  child: const Text('+1'),
                ),
                const SizedBox(width: 4),
                ElevatedButton(
                  onPressed: () => _adjustOffsetX(10),
                  child: const Text('+10'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Offset Y controls
            Text('Offset Y: ${_debugOffsetY.toStringAsFixed(1)}', style: const TextStyle(color: Colors.white)),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => _adjustOffsetY(-10),
                  child: const Text('-10'),
                ),
                const SizedBox(width: 4),
                ElevatedButton(
                  onPressed: () => _adjustOffsetY(-1),
                  child: const Text('-1'),
                ),
                const SizedBox(width: 4),
                ElevatedButton(
                  onPressed: () => _adjustOffsetY(1),
                  child: const Text('+1'),
                ),
                const SizedBox(width: 4),
                ElevatedButton(
                  onPressed: () => _adjustOffsetY(10),
                  child: const Text('+10'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Utility buttons
            Row(
              children: [
                ElevatedButton(
                  onPressed: _resetToBaseline,
                  child: const Text('Reset'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _showBoundingBoxes = !_showBoundingBoxes;
                    });
                  },
                  child: Text(_showBoundingBoxes ? 'Hide Boxes' : 'Show Boxes'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Info display
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Screen: ${widget.constraints.maxWidth.toInt()}x${widget.constraints.maxHeight.toInt()}', 
                       style: const TextStyle(color: Colors.white, fontSize: 12)),
                  Text('SVG: ${widget.sourceWidth.toInt()}x${widget.sourceHeight.toInt()}', 
                       style: const TextStyle(color: Colors.white, fontSize: 12)),
                  Text('Markers: ${widget.markers.length}', 
                       style: const TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _adjustScale(double delta) {
    setState(() {
      _debugScale = (_debugScale + delta).clamp(0.1, 5.0);
      _notifyChange();
    });
  }

  void _adjustOffsetX(double delta) {
    setState(() {
      _debugOffsetX += delta;
      _notifyChange();
    });
  }

  void _adjustOffsetY(double delta) {
    setState(() {
      _debugOffsetY += delta;
      _notifyChange();
    });
  }

  void _resetToBaseline() {
    final double scaleX = widget.constraints.maxWidth / widget.sourceWidth;
    final double scaleY = widget.constraints.maxHeight / widget.sourceHeight;
    final double svgScale = scaleX < scaleY ? scaleX : scaleY;
    
    final double renderedWidth = widget.sourceWidth * svgScale;
    final double renderedHeight = widget.sourceHeight * svgScale;
    
    setState(() {
      _debugScale = svgScale;
      _debugOffsetX = (widget.constraints.maxWidth - renderedWidth) / 2;
      _debugOffsetY = (widget.constraints.maxHeight - renderedHeight) / 2;
      _notifyChange();
    });
  }

  Color _getDebugColor(int index) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.cyan,
      Colors.pink,
      Colors.lime,
      Colors.indigo,
      Colors.teal,
    ];
    return colors[index % colors.length];
  }
}
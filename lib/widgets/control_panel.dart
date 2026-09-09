import 'package:flutter/material.dart';

class ControlPanel extends StatelessWidget {
  final TextEditingController boxIdController;
  final TextEditingController barCodeController;
  final TextEditingController companyCodeController;
  final bool scannerNormal;
  final bool networkConnected;
  final int currentCount;
  final int totalCount;
  final VoidCallback onSend;
  final VoidCallback onClearScreen;

  const ControlPanel({
    super.key,
    required this.boxIdController,
    required this.barCodeController,
    required this.companyCodeController,
    required this.scannerNormal,
    required this.networkConnected,
    required this.currentCount,
    required this.totalCount,
    required this.onSend,
    required this.onClearScreen,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} List';
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8E8E8),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left side - Input fields
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Box Id row
                _buildInputRow('Box Id', boxIdController, const Color(0xFFD8BFD8)),
                const SizedBox(height: 4),
                // BarCode row
                _buildInputRow('BarCode', barCodeController, const Color(0xFFFFFF99)),
                const SizedBox(height: 4),
                // Company Code row
                Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        'Company Code',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      height: 24,
                      child: TextField(
                        controller: companyCodeController,
                        style: const TextStyle(fontSize: 11),
                        decoration: InputDecoration(
                          fillColor: const Color(0xFFFFFF99),
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: BorderSide(color: Colors.grey.shade400),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: BorderSide(color: Colors.grey.shade400),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // ISEMM as fixed text (not editable)
                    Container(
                      width: 80,
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                      alignment: Alignment.centerLeft,
                      child: const Text(
                        'ISEMM',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Middle - Buttons (only Send and Clear Screen)
          Column(
            children: [
              // Send button
              _buildActionButton('Send', const Color(0xFF9B59B6), onSend),
              const SizedBox(height: 4),
              // Clear Screen button
              _buildActionButton('Clear Screen', const Color(0xFF3498DB), onClearScreen),
            ],
          ),
          
          const SizedBox(width: 16),
          
          // Status indicators (no checkboxes)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusIndicator('Scanner:', scannerNormal ? 'Normal' : 'Error', scannerNormal),
              const SizedBox(height: 4),
              _buildStatusIndicator('Network:', networkConnected ? 'Connect' : 'Disconnect', networkConnected),
            ],
          ),
          
          const Spacer(),
          
          // Right side - Counter and date
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Counter display
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontFamily: 'Arial'),
                  children: [
                    TextSpan(
                      text: '$currentCount',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const TextSpan(
                      text: '/',
                      style: TextStyle(
                        fontSize: 36,
                        color: Colors.black54,
                      ),
                    ),
                    TextSpan(
                      text: '$totalCount',
                      style: const TextStyle(
                        fontSize: 36,
                        color: Colors.black54,
                      ),
                    ),
                    const TextSpan(
                      text: ' items',
                      style: TextStyle(
                        fontSize: 24,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                dateStr,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow(String label, TextEditingController controller, Color fillColor) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
        ),
        Expanded(
          child: SizedBox(
            height: 24,
            child: TextField(
              controller: controller,
              style: const TextStyle(fontSize: 11),
              decoration: InputDecoration(
                fillColor: fillColor,
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: 100,
      height: 28,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        child: Text(label, style: const TextStyle(fontSize: 11)),
      ),
    );
  }

  Widget _buildStatusIndicator(String label, String status, bool isGood) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 4),
        Text(
          status,
          style: TextStyle(
            fontSize: 11,
            color: isGood ? Colors.blue : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 4),
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isGood ? Colors.blue : Colors.red,
            boxShadow: [
              BoxShadow(
                color: (isGood ? Colors.blue : Colors.red).withValues(alpha: 0.5),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

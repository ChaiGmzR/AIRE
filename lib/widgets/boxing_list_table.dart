import 'package:flutter/material.dart';
import '../models/box_scan.dart';

class BoxingListTable extends StatelessWidget {
  final List<BoxScan> boxScans;
  final int? selectedRowIndex;
  final ValueChanged<int> onRowSelected;
  final VoidCallback onDeleteSelected;

  const BoxingListTable({
    super.key,
    required this.boxScans,
    required this.selectedRowIndex,
    required this.onRowSelected,
    required this.onDeleteSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with title and delete button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: const Color(0xFFE0E0E0),
            child: Row(
              children: [
                const Text(
                  'Boxing List',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                // Delete button (1건 삭제 = Delete 1 item)
                SizedBox(
                  height: 24,
                  child: ElevatedButton(
                    onPressed: selectedRowIndex != null ? onDeleteSelected : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE74C3C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(2),
                      ),
                      disabledBackgroundColor: Colors.grey.shade400,
                    ),
                    child: const Text('Delete 1 Item', style: TextStyle(fontSize: 10)),
                  ),
                ),
              ],
            ),
          ),
          
          // Table header
          Container(
            color: const Color(0xFF2C3E50),
            child: Row(
              children: [
                _buildHeaderCell('No', 50),
                _buildHeaderCell('Box Id', 150),
                _buildHeaderCell('BarCode', 200),
                _buildHeaderCell('Read Time', 150),
              ],
            ),
          ),
          
          // Table body
          Expanded(
            child: ListView.builder(
              itemCount: boxScans.length,
              itemBuilder: (context, index) {
                final scan = boxScans[index];
                final isSelected = selectedRowIndex == index;
                final isEven = index % 2 == 0;
                
                return InkWell(
                  onTap: () => onRowSelected(index),
                  child: Container(
                    color: isSelected
                        ? const Color(0xFF3498DB).withValues(alpha: 0.3)
                        : isEven
                            ? const Color(0xFFF5F5F5)
                            : Colors.white,
                    child: Row(
                      children: [
                        _buildDataCell(scan.no.toString(), 50),
                        _buildDataCell(scan.boxId, 150),
                        _buildDataCell(scan.barCode, 200),
                        _buildDataCell(scan.formattedReadTime, 150),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildDataCell(String text, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

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
      color: const Color(0xFFE0E0E0),
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
                  'Lista de escaneo',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 16),
                // Delete button (1건 삭제 = Delete 1 item)
                SizedBox(
                  height: 24,
                  child: ElevatedButton(
                    onPressed: selectedRowIndex != null
                        ? onDeleteSelected
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE74C3C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(2),
                      ),
                      disabledBackgroundColor: Colors.grey.shade400,
                    ),
                    child: const Text(
                      'Delete 1 Item',
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Table header
                  Container(
                    color: const Color(0xFF2C3E50),
                    child: Row(
                      children: [
                        _buildHeaderCell('No.', 1),
                        _buildHeaderCell('Box Id', 3),
                        _buildHeaderCell('BarCode', 4),
                        _buildHeaderCell('Hora', 3),
                      ],
                    ),
                  ),

                  // Table body
                  Expanded(
                    child: ListView.builder(
                      itemCount: boxScans.length > 100 ? boxScans.length : 100,
                      itemBuilder: (context, index) {
                        final scan = index < boxScans.length
                            ? boxScans[index]
                            : null;
                        final isSelected = scan != null &&
                            selectedRowIndex == index;
                        final isEven = index % 2 == 0;

                        return InkWell(
                          onTap: scan == null ? null : () => onRowSelected(index),
                          child: Container(
                            color: isSelected
                                ? const Color(0xFF3498DB).withValues(alpha: 0.3)
                                : isEven
                                ? const Color(0xFFF5F5F5)
                                : Colors.white,
                            child: Row(
                              children: [
                                _buildDataCell('${index + 1}', 1),
                                _buildDataCell(scan?.boxId ?? '', 3),
                                _buildDataCell(scan?.barCode ?? '', 4),
                                _buildDataCell(
                                  scan?.formattedReadTime ?? '',
                                  3,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, int flex) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white24),
        ),
      ),
    );
  }

  Widget _buildDataCell(String text, int flex) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          text,
          maxLines: 1,
          style: const TextStyle(fontSize: 10),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

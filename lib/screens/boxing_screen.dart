import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/top_header.dart';
import '../widgets/boxing_list_table.dart';
import '../models/box_scan.dart';
import '../services/api_service.dart';

class BoxingScreen extends StatefulWidget {
  const BoxingScreen({super.key});

  @override
  State<BoxingScreen> createState() => _BoxingScreenState();
}

class _BoxingScreenState extends State<BoxingScreen> {
  final TextEditingController boxIdController = TextEditingController();
  final TextEditingController barCodeController = TextEditingController();
  final TextEditingController companyCodeController = TextEditingController(text: '92');
  
  final FocusNode boxIdFocusNode = FocusNode();
  final FocusNode barCodeFocusNode = FocusNode();
  
  bool boxIdLocked = false;
  bool scannerNormal = true;
  bool networkConnected = false;
  bool isProcessing = false;
  
  int currentBoxCount = 0;
  int shiftCount = 0;
  String? currentPartNumber;
  
  List<BoxScan> boxScans = [];

  @override
  void initState() {
    super.initState();
    _checkApiConnection();
    
    // Auto-focus on Box Id field on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      boxIdFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    boxIdController.dispose();
    barCodeController.dispose();
    companyCodeController.dispose();
    boxIdFocusNode.dispose();
    barCodeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _checkApiConnection() async {
    final status = await ApiService.getStatus();
    setState(() {
      networkConnected = status.connected;
    });
  }

  void _onBoxIdSubmitted(String value) {
    if (value.trim().isNotEmpty) {
      setState(() {
        boxIdLocked = true;
      });
      // Move focus to BarCode field
      barCodeFocusNode.requestFocus();
    }
  }

  Future<void> _onBarCodeSubmitted(String value) async {
    if (value.trim().isEmpty || !boxIdLocked || isProcessing) return;

    setState(() {
      isProcessing = true;
    });

    try {
      final result = await ApiService.registerScan(
        boxCode: boxIdController.text.trim(),
        barcode: value.trim(),
      );

      if (result.success) {
        // Add to local list
        setState(() {
          currentBoxCount = result.boxCount ?? (currentBoxCount + 1);
          shiftCount = result.shiftCount ?? shiftCount;
          currentPartNumber = result.partNumber;
          
          boxScans.insert(0, BoxScan(
            no: currentBoxCount,
            boxId: boxIdController.text.trim(),
            barCode: result.serial ?? value.trim(),
            readTime: DateTime.now(),
          ));
        });
        
        // Clear barcode field and keep focus
        barCodeController.clear();
      } else {
        _showError(result.error ?? 'Error registering scan');
      }
    } catch (e) {
      _showError('Connection error: $e');
    } finally {
      setState(() {
        isProcessing = false;
      });
      // Keep focus on barcode field for next scan
      barCodeFocusNode.requestFocus();
    }
  }

  Future<void> _onSend() async {
    if (!boxIdLocked || boxScans.isEmpty) {
      _showError('Please scan at least one piece before sending');
      return;
    }

    // Show confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Send'),
        content: Text('Send ${boxScans.length} pieces for box ${boxIdController.text}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        isProcessing = true;
      });

      final result = await ApiService.sendBox(boxIdController.text.trim());
      if (!mounted) return;

      setState(() {
        isProcessing = false;
      });

      if (result.success) {
        final fileName = result.fileName ?? 'BOX file';
        _resetForm();
        _showSuccess('Generated $fileName');
      } else {
        _showError(result.error ?? 'Error generating BOX file');
        barCodeFocusNode.requestFocus();
      }
    }
  }

  Future<void> _onClearScreen() async {
    if (boxScans.isEmpty && !boxIdLocked) {
      // Nothing to clear
      boxIdFocusNode.requestFocus();
      return;
    }

    // Confirm clear if there are scans
    if (boxScans.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Clear Screen'),
          content: Text('Clear ${boxScans.length} scanned pieces? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Clear pending scans from backend memory
      if (boxIdController.text.isNotEmpty) {
        await ApiService.clearBoxScans(boxIdController.text.trim());
      }
    }

    _resetForm();
  }

  void _resetForm() {
    setState(() {
      boxIdController.clear();
      barCodeController.clear();
      boxIdLocked = false;
      boxScans.clear();
      currentBoxCount = 0;
      currentPartNumber = null;
    });
    boxIdFocusNode.requestFocus();
  }

  void _onDeleteSelected() {
    // Note: Individual delete not implemented as per original UI
    // Pieces are committed as a batch
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Top Header with Ilsan Packing System
          const TopHeader(),
          
          // Main content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Column(
                children: [
                  // Control Panel with scanner handling
                  _buildControlPanel(),
                  
                  const SizedBox(height: 8),
                  
                  // Boxing List Table
                  Expanded(
                    child: BoxingListTable(
                      boxScans: boxScans,
                      selectedRowIndex: null,
                      onRowSelected: (_) {},
                      onDeleteSelected: _onDeleteSelected,
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

  Widget _buildControlPanel() {
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
                _buildBoxIdRow(),
                const SizedBox(height: 4),
                // BarCode row
                _buildBarCodeRow(),
                const SizedBox(height: 4),
                // Company Code row
                _buildCompanyCodeRow(),
              ],
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Middle - Buttons
          Column(
            children: [
              _buildActionButton('Send', const Color(0xFF9B59B6), _onSend),
              const SizedBox(height: 4),
              _buildActionButton('Clear Screen', const Color(0xFF3498DB), _onClearScreen),
            ],
          ),
          
          const SizedBox(width: 16),
          
          // Status indicators
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
          _buildCounterDisplay(),
        ],
      ),
    );
  }

  Widget _buildBoxIdRow() {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            'Box Id',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
        ),
        Expanded(
          child: SizedBox(
            height: 24,
            child: TextField(
              controller: boxIdController,
              focusNode: boxIdFocusNode,
              enabled: !boxIdLocked,
              style: const TextStyle(fontSize: 11),
              onSubmitted: _onBoxIdSubmitted,
              decoration: InputDecoration(
                fillColor: boxIdLocked ? Colors.grey.shade300 : const Color(0xFFD8BFD8),
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
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
              ),
            ),
          ),
        ),
        if (boxIdLocked)
          IconButton(
            icon: const Icon(Icons.lock, size: 16),
            onPressed: null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ],
    );
  }

  Widget _buildBarCodeRow() {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            'BarCode',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
        ),
        Expanded(
          child: SizedBox(
            height: 24,
            child: KeyboardListener(
              focusNode: FocusNode(),
              onKeyEvent: (event) {
                // Handle TAB key for scanner input
                if (event is KeyDownEvent &&
                    (event.logicalKey == LogicalKeyboardKey.tab ||
                     event.logicalKey == LogicalKeyboardKey.enter)) {
                  if (barCodeController.text.isNotEmpty) {
                    _onBarCodeSubmitted(barCodeController.text);
                  }
                }
              },
              child: TextField(
                controller: barCodeController,
                focusNode: barCodeFocusNode,
                enabled: boxIdLocked,
                style: const TextStyle(fontSize: 11),
                onSubmitted: _onBarCodeSubmitted,
                decoration: InputDecoration(
                  fillColor: boxIdLocked ? const Color(0xFFFFFF99) : Colors.grey.shade200,
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
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (isProcessing)
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }

  Widget _buildCompanyCodeRow() {
    return Row(
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
    );
  }

  Widget _buildCounterDisplay() {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} List';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(fontFamily: 'Arial'),
            children: [
              TextSpan(
                text: '$currentBoxCount',
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
                text: '$shiftCount',
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
        if (currentPartNumber != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Part: $currentPartNumber',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade500,
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

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_info.dart';
import '../widgets/top_header.dart';
import '../widgets/boxing_list_table.dart';
import '../models/box_scan.dart';
import '../services/api_service.dart';
import '../services/app_settings_service.dart';
import '../services/app_update_service.dart';

class BoxingScreen extends StatefulWidget {
  const BoxingScreen({super.key});

  @override
  State<BoxingScreen> createState() => _BoxingScreenState();
}

class _BoxingScreenState extends State<BoxingScreen> {
  static const String _mainPcbType = 'MAIN_PCB';
  static const String _displayType = 'DISPLAY';
  static const Map<String, String> _productionTypeLabels = {
    _mainPcbType: 'MAIN PCB',
    _displayType: 'DISPLAY',
  };
  static const Map<String, List<String>> _lineCodesByProductionType = {
    _mainPcbType: ['M1', 'M2', 'M3', 'M4'],
    _displayType: ['D1', 'D2', 'D3'],
  };

  final TextEditingController boxIdController = TextEditingController();
  final TextEditingController barCodeController = TextEditingController();
  final TextEditingController companyCodeController = TextEditingController(
    text: '92',
  );

  final FocusNode boxIdFocusNode = FocusNode();
  final FocusNode barCodeFocusNode = FocusNode();

  bool boxIdLocked = false;
  bool scannerNormal = true;
  bool networkConnected = false;
  bool isProcessing = false;
  bool _suspendAutoFocus = false;
  bool _focusScheduled = false;

  int currentBoxCount = 0;
  int shiftCount = 0;
  String? currentPartNumber;
  int? selectedRowIndex;
  String selectedProductionType = _mainPcbType;
  String selectedLineCode = 'M1';

  List<BoxScan> boxScans = [];

  List<String> get _availableLineCodes {
    return _lineCodesByProductionType[selectedProductionType] ??
        _lineCodesByProductionType[_mainPcbType]!;
  }

  @override
  void initState() {
    super.initState();
    boxIdFocusNode.addListener(_handleFocusChange);
    barCodeFocusNode.addListener(_handleFocusChange);
    unawaited(_loadSavedProductionSelection());
    _checkApiConnection();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleExpectedFocus();
      unawaited(_validateAppVersion());
    });
  }

  @override
  void dispose() {
    boxIdFocusNode.removeListener(_handleFocusChange);
    barCodeFocusNode.removeListener(_handleFocusChange);
    boxIdController.dispose();
    barCodeController.dispose();
    companyCodeController.dispose();
    boxIdFocusNode.dispose();
    barCodeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _checkApiConnection() async {
    final status = await ApiService.getStatus();
    if (!mounted) return;
    setState(() {
      networkConnected = status.connected;
    });
    _scheduleExpectedFocus();
  }

  Future<void> _validateAppVersion() async {
    final validation = await ApiService.validateVersion(
      clientVersion: AppInfo.version,
    );
    if (!mounted || validation.valid) {
      return;
    }

    final requiredVersion = validation.requiredVersion;
    if (requiredVersion != null &&
        _isNewerVersion(requiredVersion, AppInfo.version)) {
      await _showUpdateDialog(requiredVersion);
      return;
    }

    _showError(validation.message);
    _scheduleExpectedFocus();
  }

  Future<void> _showUpdateDialog(String requiredVersion) async {
    var isDownloading = false;
    String? updateError;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Nueva version disponible'),
            content: Text(
              isDownloading
                  ? 'Descargando la version $requiredVersion...'
                  : updateError ??
                      'La version instalada es ${AppInfo.version}. '
                          'Esta disponible la version $requiredVersion.',
            ),
            actions: [
              if (!isDownloading)
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cerrar'),
                ),
              if (!isDownloading)
                FilledButton(
                  onPressed: () async {
                    setDialogState(() {
                      isDownloading = true;
                      updateError = null;
                    });

                    try {
                      await AppUpdateService.downloadAndLaunchInstaller(
                        requiredVersion,
                      );
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                      exit(0);
                    } catch (error) {
                      if (!dialogContext.mounted) return;
                      setDialogState(() {
                        isDownloading = false;
                        updateError =
                            'No se pudo descargar la actualizacion: $error';
                      });
                    }
                  },
                  child: const Text('Actualizar ahora'),
                ),
            ],
          );
        },
      ),
    );
  }

  bool _isNewerVersion(String candidate, String current) {
    List<int> parse(String value) {
      return value
          .split('.')
          .map((part) => int.tryParse(part) ?? 0)
          .toList();
    }

    final candidateParts = parse(candidate);
    final currentParts = parse(current);
    for (var index = 0; index < 3; index++) {
      final candidatePart = index < candidateParts.length
          ? candidateParts[index]
          : 0;
      final currentPart = index < currentParts.length
          ? currentParts[index]
          : 0;
      if (candidatePart != currentPart) {
        return candidatePart > currentPart;
      }
    }
    return false;
  }

  Future<void> _loadSavedProductionSelection() async {
    final settings = await AppSettingsService.loadProductionLineSettings();
    if (!mounted || settings == null || boxIdLocked) {
      return;
    }

    setState(() {
      _setProductionSelection(settings.productionType, settings.lineCode);
    });
    _scheduleExpectedFocus();
  }

  void _handleFocusChange() {
    if (_suspendAutoFocus) {
      return;
    }

    _scheduleExpectedFocus();
  }

  void _scheduleExpectedFocus() {
    if (_focusScheduled) {
      return;
    }

    _focusScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusScheduled = false;
      _requestExpectedFocus();
    });
  }

  void _requestExpectedFocus() {
    if (!mounted || _suspendAutoFocus) {
      return;
    }

    final expectedFocusNode = boxIdLocked ? barCodeFocusNode : boxIdFocusNode;
    if (!expectedFocusNode.hasFocus && expectedFocusNode.canRequestFocus) {
      expectedFocusNode.requestFocus();
    }
  }

  Future<void> _onBoxIdSubmitted(String value) async {
    final boxId = value.trim();
    if (boxId.isNotEmpty) {
      final validationError = ApiService.validateBoxId(boxId);
      if (validationError != null) {
        _showError(validationError);
        _scheduleExpectedFocus();
        return;
      }

      boxIdController.value = TextEditingValue(
        text: boxId,
        selection: TextSelection.collapsed(offset: boxId.length),
      );

      setState(() {
        boxIdLocked = true;
        selectedRowIndex = null;
        boxScans.clear();
        currentBoxCount = 0;
        currentPartNumber = null;
        isProcessing = false;
      });
      _scheduleExpectedFocus();
      return;
    }

    _scheduleExpectedFocus();
  }

  Future<void> _onBarCodeSubmitted(String value) async {
    final barcode = value.trim();
    if (barcode.isEmpty || !boxIdLocked || isProcessing) {
      _scheduleExpectedFocus();
      return;
    }

    final validationError = ApiService.validateBarcode(barcode);
    if (validationError != null) {
      _showError(validationError);
      barCodeController.clear();
      _scheduleExpectedFocus();
      return;
    }

    if (boxScans.any((scan) => scan.barCode == barcode)) {
      _showError('Este BarCode ya fue escaneado en esta caja');
      barCodeController.clear();
      _scheduleExpectedFocus();
      return;
    }

    final partNumber = ApiService.extractPartNumber(barcode)!;
    if (currentPartNumber != null && currentPartNumber != partNumber) {
      _showError(
        'Numero de parte distinto. Esperado $currentPartNumber, recibido $partNumber',
      );
      barCodeController.clear();
      _scheduleExpectedFocus();
      return;
    }

    setState(() {
      isProcessing = true;
    });

    try {
      final result = await ApiService.registerScan(
        boxCode: boxIdController.text.trim(),
        barcode: barcode,
        productionType: selectedProductionType,
        lineCode: selectedLineCode,
      );
      if (!mounted) return;

      if (result.success) {
        // Add to local list
        setState(() {
          currentBoxCount = boxScans.length + 1;
          shiftCount = result.shiftCount ?? shiftCount;
          currentPartNumber = result.partNumber ?? partNumber;
          selectedRowIndex = null;

          boxScans.insert(
            0,
            BoxScan(
              no: currentBoxCount,
              boxId: boxIdController.text.trim(),
              barCode: result.serial ?? barcode,
              partNumber: result.partNumber ?? partNumber,
              readTime: DateTime.now(),
            ),
          );
        });

        // Clear barcode field and keep focus
        barCodeController.clear();
      } else {
        final error = result.error ?? 'Error al registrar el escaneo';
        _showError(_displayErrorMessage(error));
        barCodeController.clear();
      }
    } catch (e) {
      _showError('Error de conexion: $e');
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
        // Keep focus on barcode field for next scan
        _scheduleExpectedFocus();
      }
    }
  }

  Future<void> _onSend() async {
    if (!boxIdLocked || boxScans.isEmpty) {
      _showError('Escanee al menos una pieza antes de enviar');
      _scheduleExpectedFocus();
      return;
    }

    setState(() {
      isProcessing = true;
    });

    final result = await ApiService.sendBox(
      boxCode: boxIdController.text.trim(),
      scans: boxScans
          .map(
            (scan) => <String, dynamic>{
              'barcode': scan.barCode,
              'firstScan': scan.readTime.toIso8601String(),
            },
          )
          .toList(),
      productionType: selectedProductionType,
      lineCode: selectedLineCode,
    );
    if (!mounted) return;

    setState(() {
      isProcessing = false;
    });

    if (result.success) {
      final fileName = result.fileName ?? 'archivo BOX';
      _resetForm();
      _showSuccess('Archivo generado: $fileName');
    } else {
      _showError(result.error ?? 'Error al generar el archivo BOX');
      _scheduleExpectedFocus();
    }
  }

  Future<void> _onClearScreen() async {
    if (boxScans.isEmpty && !boxIdLocked) {
      // Nothing to clear
      _scheduleExpectedFocus();
      return;
    }

    // Confirm clear if there are scans
    if (boxScans.isNotEmpty) {
      _suspendAutoFocus = true;
      bool? confirmed;
      try {
        confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Limpiar pantalla'),
            content: Text(
              'Limpiar ${boxScans.length} piezas escaneadas? Esta accion no se puede deshacer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Limpiar'),
              ),
            ],
          ),
        );
      } finally {
        _suspendAutoFocus = false;
      }

      if (!mounted) return;
      if (confirmed != true) {
        _scheduleExpectedFocus();
        return;
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
      selectedRowIndex = null;
    });
    _scheduleExpectedFocus();
  }

  void _onRowSelected(int index) {
    setState(() {
      selectedRowIndex = selectedRowIndex == index ? null : index;
    });
    _scheduleExpectedFocus();
  }

  void _onProductionTypeChanged(String? value) {
    if (value == null || boxIdLocked || isProcessing) {
      _scheduleExpectedFocus();
      return;
    }

    setState(() {
      _setProductionSelection(value, _lineCodesByProductionType[value]!.first);
    });
    unawaited(_saveProductionSelection());
    _scheduleExpectedFocus();
  }

  void _onLineCodeChanged(String? value) {
    if (value == null || boxIdLocked || isProcessing) {
      _scheduleExpectedFocus();
      return;
    }

    setState(() {
      _setProductionSelection(selectedProductionType, value);
    });
    unawaited(_saveProductionSelection());
    _scheduleExpectedFocus();
  }

  void _setProductionSelection(String productionType, String lineCode) {
    final validProductionType =
        _lineCodesByProductionType.containsKey(productionType)
        ? productionType
        : _mainPcbType;
    final validLines = _lineCodesByProductionType[validProductionType]!;

    selectedProductionType = validProductionType;
    selectedLineCode = validLines.contains(lineCode)
        ? lineCode
        : validLines.first;
  }

  Future<void> _saveProductionSelection() {
    return AppSettingsService.saveProductionLineSettings(
      productionType: selectedProductionType,
      lineCode: selectedLineCode,
    );
  }

  Future<void> _onDeleteSelected() async {
    final index = selectedRowIndex;
    if (index == null ||
        index < 0 ||
        index >= boxScans.length ||
        isProcessing) {
      _scheduleExpectedFocus();
      return;
    }

    setState(() {
      boxScans.removeAt(index);
      boxScans = _renumberLocalScans(boxScans);
      currentBoxCount = boxScans.length;
      currentPartNumber = boxScans.isEmpty ? null : boxScans.first.partNumber;
      shiftCount = boxScans.isEmpty ? 0 : shiftCount;
      selectedRowIndex = null;
    });
    _scheduleExpectedFocus();
  }

  List<BoxScan> _renumberLocalScans(List<BoxScan> scans) {
    final total = scans.length;
    return [
      for (var index = 0; index < scans.length; index++)
        BoxScan(
          no: total - index,
          boxId: scans[index].boxId,
          barCode: scans[index].barCode,
          partNumber: scans[index].partNumber,
          readTime: scans[index].readTime,
        ),
    ];
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

  String _displayErrorMessage(String message) {
    if (selectedProductionType != _displayType) {
      return message;
    }

    final lowerMessage = message.toLowerCase();
    final isMainPcbValidationError =
        lowerMessage.contains('ict') ||
        lowerMessage.contains('fct') ||
        lowerMessage.startsWith('ict ') ||
        lowerMessage.startsWith('fct ');

    if (!isMainPcbValidationError) {
      return message;
    }

    return 'El flujo DISPLAY no esta desplegado en el backend. Actualiza/reinicia el servidor.';
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

                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 1,
                          child: BoxingListTable(
                            boxScans: boxScans,
                            selectedRowIndex: selectedRowIndex,
                            onRowSelected: _onRowSelected,
                            onDeleteSelected: () {
                              _onDeleteSelected();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(flex: 2, child: _buildReservedWorkArea()),
                      ],
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
                _buildProductionLineRow(),
                const SizedBox(height: 4),
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
              _buildActionButton(
                'Clear Screen',
                const Color(0xFF3498DB),
                _onClearScreen,
              ),
            ],
          ),

          const SizedBox(width: 16),

          // Status indicators
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusIndicator(
                'Scanner:',
                scannerNormal ? 'Normal' : 'Error',
                scannerNormal,
              ),
              const SizedBox(height: 4),
              _buildStatusIndicator(
                'Network:',
                networkConnected ? 'Connect' : 'Disconnect',
                networkConnected,
              ),
            ],
          ),

          const Spacer(),

          // Right side - Counter and date
          _buildCounterDisplay(),
        ],
      ),
    );
  }

  Widget _buildReservedWorkArea() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400),
      ),
    );
  }

  Widget _buildProductionLineRow() {
    final selectorEnabled = !boxIdLocked && !isProcessing;

    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            'Line',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
        ),
        SizedBox(
          width: 120,
          height: 24,
          child: DropdownButtonFormField<String>(
            key: ValueKey('production-type-$selectedProductionType'),
            initialValue: selectedProductionType,
            isExpanded: true,
            isDense: true,
            style: const TextStyle(fontSize: 11, color: Colors.black),
            decoration: _buildCompactDropdownDecoration(
              enabled: selectorEnabled,
            ),
            items: _productionTypeLabels.entries
                .map(
                  (entry) => DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: selectorEnabled ? _onProductionTypeChanged : null,
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 70,
          height: 24,
          child: DropdownButtonFormField<String>(
            key: ValueKey('line-$selectedProductionType-$selectedLineCode'),
            initialValue: selectedLineCode,
            isExpanded: true,
            isDense: true,
            style: const TextStyle(fontSize: 11, color: Colors.black),
            decoration: _buildCompactDropdownDecoration(
              enabled: selectorEnabled,
            ),
            items: _availableLineCodes
                .map(
                  (lineCode) => DropdownMenuItem<String>(
                    value: lineCode,
                    child: Text(lineCode, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: selectorEnabled ? _onLineCodeChanged : null,
          ),
        ),
      ],
    );
  }

  InputDecoration _buildCompactDropdownDecoration({required bool enabled}) {
    return InputDecoration(
      fillColor: enabled ? const Color(0xFFFFFF99) : Colors.grey.shade300,
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
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
                fillColor: boxIdLocked
                    ? Colors.grey.shade300
                    : const Color(0xFFD8BFD8),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 4,
                ),
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
                  fillColor: boxIdLocked
                      ? const Color(0xFFFFFF99)
                      : Colors.grey.shade200,
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 4,
              ),
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
          child: const Text('ISEMM', style: TextStyle(fontSize: 11)),
        ),
      ],
    );
  }

  Widget _buildCounterDisplay() {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} List';

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
                style: TextStyle(fontSize: 36, color: Colors.black54),
              ),
              TextSpan(
                text: '$shiftCount',
                style: const TextStyle(fontSize: 36, color: Colors.black54),
              ),
              const TextSpan(
                text: ' items',
                style: TextStyle(fontSize: 24, color: Colors.black54),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          dateStr,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        if (currentPartNumber != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Part: $currentPartNumber',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
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
                color: (isGood ? Colors.blue : Colors.red).withValues(
                  alpha: 0.5,
                ),
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

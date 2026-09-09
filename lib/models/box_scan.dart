class BoxScan {
  final int no;
  final String boxId;
  final String barCode;
  final DateTime readTime;

  BoxScan({
    required this.no,
    required this.boxId,
    required this.barCode,
    required this.readTime,
  });

  String get formattedReadTime {
    return '${readTime.year}-${readTime.month.toString().padLeft(2, '0')}-${readTime.day.toString().padLeft(2, '0')} '
           '${readTime.hour.toString().padLeft(2, '0')}:${readTime.minute.toString().padLeft(2, '0')}:${readTime.second.toString().padLeft(2, '0')}';
  }
}

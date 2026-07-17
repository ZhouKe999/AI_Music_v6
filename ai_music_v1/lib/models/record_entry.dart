class RecordEntry {
  final int? id;
  final String date;
  final String filePath; // Path to the audio file if needed
  final String comment;
  final String? videoPath; // Path to the video file

  RecordEntry({
    this.id,
    required this.date,
    required this.filePath,
    required this.comment,
    this.videoPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'filePath': filePath,
      'comment': comment,
      'videoPath': videoPath,
    };
  }

  factory RecordEntry.fromMap(Map<String, dynamic> map) {
    return RecordEntry(
      id: map['id'],
      date: map['date'],
      filePath: map['filePath'],
      comment: map['comment'],
      videoPath: map['videoPath'],
    );
  }
}

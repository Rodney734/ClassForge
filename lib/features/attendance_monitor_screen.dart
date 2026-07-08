import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class LecturerAttendanceScreen extends StatefulWidget {
  final String sessionId;
  final String courseName;
  final String lectureTitle;

  const LecturerAttendanceScreen({
    super.key,
    required this.sessionId,
    required this.courseName,
    required this.lectureTitle,
  });

  @override
  State<LecturerAttendanceScreen> createState() =>
      _LecturerAttendanceScreenState();
}

class _LecturerAttendanceScreenState extends State<LecturerAttendanceScreen> {
  int _presentCount = 0;
  int _absentCount = 0;
  List<Map<String, dynamic>> _records = [];

  @override
  void initState() {
    super.initState();
    _loadAttendanceStats();
  }

  void _loadAttendanceStats() {
    final recordsRef = FirebaseFirestore.instance
        .collection('attendance_records')
        .where('sessionId', isEqualTo: widget.sessionId);

    recordsRef.snapshots().listen((snapshot) {
      if (!mounted) return;
      final records = snapshot.docs.map((doc) => doc.data()).toList();
      final present = records.where((r) => r['status'] == 'present').length;
      final absent = records.where((r) => r['status'] == 'absent').length;

      setState(() {
        _records = records;
        _presentCount = present;
        _absentCount = absent;
      });
    });
  }

  Future<void> _endAttendance() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[800]
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('End Attendance Session?'),
        content: const Text(
          'This will close the attendance session and allow you to download a report.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('End Session'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('attendance_sessions')
          .doc(widget.sessionId)
          .update({'status': 'closed'});

      await _generateAndDownloadPDF();

      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _generateAndDownloadPDF() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Attendance Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text('Course: ${widget.courseName}'),
                pw.Text('Lecture: ${widget.lectureTitle}'),
                pw.Text(
                  'Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                ),
                pw.SizedBox(height: 20),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  color: PdfColors.grey300,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Students: ${_records.length}'),
                      pw.Text(
                        'Present: $_presentCount',
                        style: const pw.TextStyle(color: PdfColors.green),
                      ),
                      pw.Text(
                        'Absent: $_absentCount',
                        style: const pw.TextStyle(color: PdfColors.red),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Student Attendance List',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
              ],
            ),
          ),
          pw.Table.fromTextArray(
            headers: ['No.', 'Student Name', 'Status', 'Distance (m)', 'Time'],
            data: List.generate(_records.length, (index) {
              final record = _records[index];
              final timestamp = (record['timestamp'] as Timestamp).toDate();
              return [
                (index + 1).toString(),
                record['studentName'] ?? 'Unknown',
                record['status'] == 'present' ? 'Present ✓' : 'Absent ✗',
                record['distance']?.toStringAsFixed(2) ?? 'N/A',
                '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
              ];
            }),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'attendance_${widget.sessionId}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.lectureTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.redAccent, Color.fromARGB(255, 172, 73, 73)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _generateAndDownloadPDF,
          ),
        ],
      ),
      body: Container(
        child: Column(
          // This Column will now directly sit on the transparent Scaffold
          children: [
            const SizedBox(height: 80),

            // Stats Cards with Glass Effect
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: _statCard('Present', _presentCount, Colors.green),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _statCard('Absent', _absentCount, Colors.red),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _statCard('Total', _records.length, Colors.blue),
                  ),
                ],
              ),
            ),

            // Student List with Glass Effect
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('attendance_records')
                    .where('sessionId', isEqualTo: widget.sessionId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final records = snapshot.data!.docs;

                  if (records.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text('No students have marked attendance yet'),
                          const SizedBox(height: 8),
                          const Text('Waiting for students to respond...'),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      final data =
                          records[index].data() as Map<String, dynamic>;
                      final isPresent = data['status'] == 'present';
                      final distance = data['distance'];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              (isDarkMode ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.1),
                              (isDarkMode ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isPresent ? Colors.green : Colors.red,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isPresent
                                    ? Colors.green.withValues(alpha: 0.2)
                                    : Colors.red.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isPresent ? Icons.check_circle : Icons.cancel,
                                color: isPresent ? Colors.green : Colors.red,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['studentName'] ?? 'Unknown',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        size: 14,
                                        color: isPresent
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Distance: ${distance?.toStringAsFixed(1) ?? 'N/A'} meters',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isPresent
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'Time: ${_formatTime(data['timestamp'])}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDarkMode
                                          ? Colors.white54
                                          : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isPresent
                                      ? [Colors.green, Colors.green.shade700]
                                      : [Colors.red, Colors.red.shade700],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isPresent ? 'PRESENT' : 'ABSENT',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // End Session Button
            Container(
              padding: const EdgeInsets.all(20),
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Colors.redAccent,
                      Color.fromARGB(255, 143, 53, 53),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _endAttendance,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'END ATTENDANCE SESSION',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String title, int count, Color color) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final date = timestamp.toDate();
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
  }
}

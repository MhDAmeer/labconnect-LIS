import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/lab_result.dart';
import '../../data/repositories/order_repository.dart';
import '../network/api_exception.dart';

/// Gets the result report PDF from the server and hands it to the phone:
/// "View" opens the system PDF viewer, "Download" saves the file under the
/// server's name and offers the share sheet.
class ReportService {
  ReportService(this._orders);

  final OrderRepository _orders;

  Future<void> view(OrderResults order) async {
    final file = await _orders.reportPdf(order.orderId);
    final dir = await getTemporaryDirectory();
    final saved = await _write(dir, _safeName(file.fileName, order), file.bytes);

    final opened = await OpenFilex.open(saved.path, type: 'application/pdf');
    if (opened.type != ResultType.done) {
      throw const ApiException(
        ApiErrorKind.unknown,
        'No PDF viewer found on this phone. Use Download PDF instead.',
      );
    }
  }

  Future<void> download(OrderResults order) async {
    final file = await _orders.reportPdf(order.orderId, forDownload: true);
    final dir = await getApplicationDocumentsDirectory();
    final saved = await _write(dir, _safeName(file.fileName, order), file.bytes);

    await Share.shareXFiles(
      [XFile(saved.path, mimeType: 'application/pdf')],
      subject: order.orderNumber,
    );
  }

  /// Deletes every report file we saved (they contain patient data). Called
  /// on logout and when the session ends.
  Future<void> clearCache() async {
    for (final getDir in [getTemporaryDirectory, getApplicationDocumentsDirectory]) {
      try {
        final root = await getDir();
        final reports = Directory('${root.path}/reports');
        if (await reports.exists()) await reports.delete(recursive: true);
      } catch (_) {
        // Nothing useful to do if the OS refuses; try the next folder.
      }
    }
  }

  Future<File> _write(Directory root, String name, List<int> bytes) async {
    final folder = Directory('${root.path}/reports');
    if (!await folder.exists()) await folder.create(recursive: true);
    final file = File('${folder.path}/$name');
    return file.writeAsBytes(bytes, flush: true);
  }

  /// The server names the file ORD-...-result-report.pdf; when it doesn't
  /// send a name we build the same pattern ourselves.
  String _safeName(String? fromServer, OrderResults order) {
    final raw = (fromServer != null && fromServer.isNotEmpty)
        ? fromServer
        : '${order.orderNumber}-result-report.pdf';
    final cleaned = raw.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return cleaned.toLowerCase().endsWith('.pdf') ? cleaned : '$cleaned.pdf';
  }
}

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  Future<void> generateAndPrintPdf(
      String fileName,
      List<String> columns,
      List<Map<String, dynamic>> data,
      ) async {
    final pdf = pw.Document();

    final filteredData = data.where((row) {
      return columns.any((col) {
        final val = row[col]?.toString() ?? "";
        return val.isNotEmpty && val != "0";
      });
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.copyWith(
          marginBottom: 10,
          marginTop: 10,
          marginLeft: 10,
          marginRight: 10,
        ),
        build: (context) => [
          pw.Header(level: 0, child: pw.Text("Report: $fileName")),
          pw.TableHelper.fromTextArray(
            headers: columns.map((e) => e.toUpperCase()).toList(),
            data: filteredData.map((row) {
              return columns.map((col) {
                final val = row[col]?.toString() ?? "";
                return (val == "0") ? "" : val;
              }).toList();
            }).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }
}
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart'; // Perubahan: Import untuk meluncurkan URL

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blueGrey),
      home: const QRViewExample(),
    );
  }
}

class QRViewExample extends StatefulWidget {
  const QRViewExample({super.key});

  @override
  State<StatefulWidget> createState() => _QRViewExampleState();
}

class _QRViewExampleState extends State<QRViewExample> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  Barcode? result;
  QRViewController? controller;

  @override
  void reassemble() {
    super.reassemble();
    controller?.pauseCamera();
    controller?.resumeCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Safe Scanner Kelompok7')),
      body: Column(
        children: <Widget>[
          Expanded(flex: 4, child: _buildQrView(context)),
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (result != null)
                  Text('Result: ${result!.code}')
                else
                  const Text('Scan a code'),
                ElevatedButton(
                  onPressed: result != null && result!.code != null
                      ? () => _checkWithVirusTotal(result!.code!)
                      : null,
                  child: const Text('Check with VirusTotal'),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildQrView(BuildContext context) {
    return QRView(
      key: qrKey,
      onQRViewCreated: _onQRViewCreated,
      overlay: QrScannerOverlayShape(
        borderColor: Colors.white,
        borderRadius: 10,
        borderLength: 30,
        borderWidth: 10,
        cutOutSize: MediaQuery.of(context).size.width * 0.8,
      ),
     //cameraFacing: CameraFacing.front, // Kamera depan
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      this.controller = controller;
    });
    controller.scannedDataStream.listen((scanData) {
      setState(() {
        result = scanData;
      });
    });
  }

  // Future<void> _checkWithVirusTotal(String url) async {
  //   const apiKey = '79a5d969d9e96f6a6e2101d6827780b7d2630d2d6e49118726ca06978501996e'; //API VirusTotal
  //   final encodedUrl = base64Url.encode(utf8.encode(url)).replaceAll('=', ''); // Encode and remove padding
  //   final apiUrl = 'https://www.virustotal.com/api/v3/urls/$encodedUrl';

  //   try {
  //     final response = await http.get(
  //       Uri.parse(apiUrl),
  //       headers: {
  //         'x-apikey': apiKey,
  //         'Content-Type': 'application/json',
  //       },
  //     );

  //     if (response.statusCode == 200) {
  //       final jsonResponse = json.decode(response.body);
  //       final scanResult = jsonResponse['data']['attributes']['last_analysis_stats'];

  //       // Perubahan: memeriksa apakah ada deteksi malicious atau suspicious
  //       if (scanResult['malicious'] > 0 || scanResult['suspicious'] > 0) {
  //         _showDangerousUrlDialog(); // Menampilkan dialog peringatan
  //       } else {
  //         _showSafeUrlDialog(url); // Menampilkan dialog untuk membuka URL
  //       }
  //     } else {
  //       _showErrorDialog('Error: Unable to scan the URL with VirusTotal.');
  //     }
  //   } catch (e) {
  //     _showErrorDialog('Error: $e');
  //   }
  // }

Future<void> _checkWithVirusTotal(String url) async {
  const apiKey = '79a5d969d9e96f6a6e2101d6827780b7d2630d2d6e49118726ca06978501996e';
  const scanUrl = 'https://www.virustotal.com/api/v3/urls';

  try {
    // Mengirim URL untuk diproses
    final response = await http.post(
      Uri.parse(scanUrl),
      headers: {
        'x-apikey': apiKey,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: 'url=$url',
    );

    print('Response from VirusTotal (Scan): ${response.body}'); // Debug log

    if (response.statusCode == 200 || response.statusCode == 201) {
      final jsonResponse = json.decode(response.body);
      final analysisId = jsonResponse['data']['id'];

      // Wait beberapa detik sebelum mengambil hasil scan
      await Future.delayed(const Duration(seconds: 5));

      _getScanResult(analysisId); // Memanggil fungsi untuk mengambil hasil scan
    } else {
      _showErrorDialog('Gagal mengirim URL ke VirusTotal.\n${response.body}');
    }
  } catch (e) {
    _showErrorDialog('Terjadi kesalahan: $e');
  }
}

// Fungsi untuk mengambil hasil scan berdasarkan analysis_id
Future<void> _getScanResult(String analysisId) async {
  const apiKey = '79a5d969d9e96f6a6e2101d6827780b7d2630d2d6e49118726ca06978501996e';
  final resultUrl = 'https://www.virustotal.com/api/v3/analyses/$analysisId';

  try {
    final response = await http.get(
      Uri.parse(resultUrl),
      headers: {
        'x-apikey': apiKey,
      },
    );

    print('Response from VirusTotal (Result): ${response.body}'); // Debug log

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      final scanResult = jsonResponse['data']['attributes']['stats'];

      int malicious = scanResult['malicious'];
      int suspicious = scanResult['suspicious'];

      if (malicious > 0 || suspicious > 0) {
        _showDangerousUrlDialog();
      } else {
        _showSafeUrlDialog(jsonResponse['meta']['url_info']['url']);
      }
    } else {
      _showErrorDialog('Gagal mengambil hasil scan.\n${response.body}');
    }
  } catch (e) {
    _showErrorDialog('Terjadi kesalahan: $e');
  }
}


  // Perubahan: Menampilkan dialog peringatan jika URL berbahaya
  void _showDangerousUrlDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Warning'),
        content: const Text('Link/URL Website Berbahaya.'),
        actions: <Widget>[
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  // Perubahan: Menampilkan dialog untuk membuka URL jika aman
  void _showSafeUrlDialog(String url) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Safe URL'),
        content: const Text('Url ini aman, silahkan dibuka'),
        actions: <Widget>[
          TextButton(
            child: const Text('Open'),
            onPressed: () {
              _launchURL(url); // Memanggil fungsi untuk membuka URL
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  // Perubahan: Fungsi untuk membuka URL di browser
  // void _launchURL(String url) async {
  //   final uri = Uri.parse(url.trim()); // Mendefinisikan uri
  //   print('Trying to launch URL: $url'); // Log untuk debugging
  //   // update jadi canLaunchUrl(uri) karena sudah deprecated 
  //   if (await canLaunchUrl(uri)) {
  //     // update jadi launchUrl(uri) karena sudah deprecated 
  //   print('canLaunchUrl returned true'); // Log untuk debugging
  //     await launchUrl(uri, mode: LaunchMode.externalApplication);
  //   print('URL launched successfully'); // Log untuk debugging
  //   } else {
  //   print('canLaunchUrl returned false'); // Log untuk debugging
  //     _showErrorDialog('Could not launch $url');
  //   }
  // }

void _launchURL(String url) async {
  final Uri uri = Uri.parse(url.trim());

  if (await canLaunchUrl(uri)) {
    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication, // Memastikan dibuka di browser eksternal
    );
  } else {
    // Menggunakan metode fallback dengan intent Android langsung
    final fallbackUri = Uri.parse("https://www.google.com/search?q=$url");
    await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
  }
}


  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}

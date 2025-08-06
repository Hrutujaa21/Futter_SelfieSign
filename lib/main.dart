import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(NativeIntegrationApp());
}

class NativeIntegrationApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter + Native iOS Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: NativeIntegrationPage(),
    );
  }
}

class NativeIntegrationPage extends StatefulWidget {
  @override
  _NativeIntegrationPageState createState() => _NativeIntegrationPageState();
}

class _NativeIntegrationPageState extends State<NativeIntegrationPage> {
  static const platform = MethodChannel('com.flutter.native/channel');

  String _result = 'Awaiting native response...';

  Future<void> _captureSelfie() async {
  try {
    final base64 = await platform.invokeMethod<String>('captureSelfie');

    if (base64 == null || base64.isEmpty) {
      // Nothing was captured — likely user canceled
      setState(() {
        _result = '';
      });
      return;
    }

    print('📸 Selfie Base64 (first 100 chars): ${base64.substring(0, 100)}...');
    setState(() {
      _result = '📸 Selfie Base64:\n${base64.substring(0, 200)}...';
    });
  } on PlatformException catch (e) {
    print('❌ Error capturing selfie: ${e.code} - ${e.message}');

    setState(() {
      _result = e.code == "USER_CANCELLED" ? '' : '❌ Error: ${e.message}';
    });
  }
}

  Future<void> _captureSingleSignature() async {
  try {
    final result = await platform.invokeMethod<String>('captureSingleSignature');

    if (result == null || result.isEmpty) {
      // Edge case: native side returned nothing
      setState(() {
        _result = '';
      });
      return;
    }

    final decoded = json.decode(result);
    print('📄 Signature JSON: $result');
    print('📄 Document (base64 prefix): ${decoded['document']?.substring(0, 100)}...');
    print('✍️ Signature (base64 prefix): ${decoded['signature']?.substring(0, 100)}...');

    setState(() {
      _result =
          '📄 Document:\n${decoded['document']?.substring(0, 200)}...\n\n'
          '✍️ Signature:\n${decoded['signature']?.substring(0, 200)}...';
    });
  } on PlatformException catch (e) {
    print('❌ Error capturing signature: ${e.message}');

    // Clear result if user cancelled or error occurred
    setState(() {
      _result = '';
    });
  }
}

 Future<void> _captureDualSignature() async {
  try {
    final result = await platform.invokeMethod<String>('captureDualSignature');

    if (result == null || result.isEmpty) {
      // Nothing returned from native code (e.g. cancel or early exit)
      setState(() {
        _result = '';
      });
      return;
    }

    final decoded = json.decode(result);
    print('📄 Dual Signature JSON: $result');
    print('📄 Document (base64 prefix): ${decoded['document']?.substring(0, 100)}...');
    print('✍️ Signature 1 (base64 prefix): ${decoded['signature1']?.substring(0, 100)}...');
    print('✍️ Signature 2 (base64 prefix): ${decoded['signature2']?.substring(0, 100)}...');

    setState(() {
      _result =
          '📄 Document:\n${decoded['document']?.substring(0, 200)}...\n\n'
          '✍️ Signature 1:\n${decoded['signature1']?.substring(0, 200)}...\n\n'
          '✍️ Signature 2:\n${decoded['signature2']?.substring(0, 200)}...';
    });
  } on PlatformException catch (e) {
    print('❌ Error capturing dual signature: ${e.code} - ${e.message}');

    setState(() {
      // Optional: show nothing if user cancelled, otherwise show the error
      _result = e.code == "USER_CANCELLED" ? '' : '❌ Error: ${e.message}';
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('SignatureSelfie POC'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        
        
        child: Center(
        child: Column(
        
          children: [
            ElevatedButton(
              onPressed: _captureSelfie,
              child: Text('📸 Capture Selfie'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _captureSingleSignature,
              child: Text('✍️ Capture Single Signature'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _captureDualSignature,
              child: Text('✍️✍️ Capture Dual Signature'),
            ),
            SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  _result,
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
        ),
        
        
        ),
        
        
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({Key? key}) : super(key: key);

  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<FileSystemEntity>? _files;

  @override
  void initState() {
    super.initState();
    _loadHistoryFiles();
  }

  Future<void> _loadHistoryFiles() async {
    Directory directory;
    if (Platform.isAndroid) {
      // Pastikan path sesuai dengan tempat Anda menyimpan file PDF
      directory = Directory('/storage/emulated/0/Download');
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    // Ambil file PDF di dalam direktori
    List<FileSystemEntity> files = directory.listSync().where((entity) {
      return entity.path.endsWith('.pdf');
    }).toList();

    setState(() {
      _files = files;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Riwayat"),
      ),
      body: _files == null
          ? Center(child: CircularProgressIndicator())
          : _files!.isEmpty
              ? Center(child: Text("No history found."))
              : ListView.builder(
                  itemCount: _files!.length,
                  itemBuilder: (context, index) {
                    FileSystemEntity file = _files![index];
                    String fileName = file.path.split('/').last;
                    return ListTile(
                      title: Text(fileName),
                      onTap: () async {
                        await OpenFile.open(file.path);
                      },
                    );
                  },
                ),
    );
  }
}

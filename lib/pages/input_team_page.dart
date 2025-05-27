import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:takraw_analyst/data/database/database_helper.dart';
import 'game_session_page.dart';

class PlayerInputPage extends StatefulWidget {
  @override
  _PlayerInputPageState createState() => _PlayerInputPageState();
}

class _PlayerInputPageState extends State<PlayerInputPage> {
  final TextEditingController _teamNameController = TextEditingController();
  final TextEditingController _playerNameController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();
  String? _selectedPosition;
  List<Map<String, dynamic>> _players = [];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky); // Hide status bar
    _loadPlayers();
  }

  Future<void> _loadPlayers() async {
    final playersFromDB = await DatabaseHelper.instance.getPlayers();
    setState(() {
      _players = playersFromDB.map((player) {
        // Buat salinan baru dengan spread operator dan tambahkan field 'scores'
        return {
          ...player,
          'scores': {},
        };
      }).toList();
    });
  }

  Future<void> _addPlayer() async {
    if (_playerNameController.text.isNotEmpty &&
        _selectedPosition != null &&
        _numberController.text.isNotEmpty &&
        _teamNameController.text.isNotEmpty) {
      // Ensure team name is entered

      await DatabaseHelper.instance.addPlayer(
        _playerNameController.text,
        _selectedPosition!,
        _numberController.text,
        _teamNameController.text, // Save team name with player
      );

      _playerNameController.clear();
      _selectedPosition = null;
      _numberController.clear();
      _loadPlayers(); // Refresh data
    }
  }

  Future<void> _resetPlayers() async {
    await DatabaseHelper.instance.resetPlayers();
    await DatabaseHelper.instance.resetScores();
    _teamNameController.clear();
    _loadPlayers();
  }

  void _editPlayerDialog(BuildContext context, int index) {
    TextEditingController nameController =
        TextEditingController(text: _players[index]['name']);
    TextEditingController numberController =
        TextEditingController(text: _players[index]['number'].toString());

    String? selectedPosition = _players[index]['position'];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Edit Player'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTextFieldWithoutUnderline(
                      nameController, "Enter Player Name"),
                  Container(
                    margin: EdgeInsets.symmetric(vertical: 2),
                    height: 40,
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey),
                      color: Colors.transparent,
                    ),
                    child: DropdownButton<String>(
                      value: selectedPosition,
                      isExpanded: true,
                      hint:
                          Text("Pilih posisi", style: TextStyle(fontSize: 12)),
                      underline: SizedBox(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedPosition = newValue;
                        });
                      },
                      items:
                          ["Tekong", "Striker", "Feeder"].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, style: TextStyle(fontSize: 12)),
                        );
                      }).toList(),
                    ),
                  ),
                  _buildTextFieldWithoutUnderline(
                      numberController, "Enter Player Number"),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context), // Close dialog
                  child: Text('Cancel', style: TextStyle(color: Colors.white)),
                ),
                TextButton(
                  onPressed: () async {
                    // ✅ Update the player in the database
                    await DatabaseHelper.instance.updatePlayer(
                      id: _players[index]['id'],
                      teamName: _teamNameController
                          .text, // Ensure team name is stored correctly
                      name: nameController.text,
                      position: selectedPosition ?? _players[index]['position'],
                      number: numberController.text.isNotEmpty
                          ? numberController.text // Store as a string
                          : _players[index]
                              ['number'], // Keep existing value if empty
                    );

                    // ✅ Refresh the list of players from the database
                    await _loadPlayers();

                    // ✅ Close the dialog
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child:
                      Text('Save', style: TextStyle(color: Colors.lightGreen)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // In PlayerInputPage _startGame
  void _startGame(String opponentName) {
    if (_players.length >= 3) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GameSessionPage(
            teamName: _teamNameController.text,
            opponentTeam: opponentName,
            players: _players
                .map((player) => {
                      "id": int.tryParse(player["id"].toString()) ?? 0,
                      "name": player["name"],
                      "position": player["position"],
                      "number": player["number"].toString(),
                      "scores": player["scores"] ?? {}
                    })
                .toList(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Stack(
            children: [
              // Full-Screen Background Image
              Positioned.fill(
                child: Image.asset(
                  'assets/mainbg.png',
                  fit: BoxFit.fill, // Cover the entire screen
                ),
              ),
              // SafeArea for UI Content
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: EdgeInsets.only(
                              top: 16, left: 8), // Adjust the value as needed
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInputLabel("NAMA TIM"),
                              _buildTextField(
                                  _teamNameController, "Masukan nama tim..."),
                              _buildInputLabel("NAMA PEMAIN"),
                              _buildTextField(_playerNameController,
                                  "Masukan nama pemain..."),
                              _buildInputLabel("POSISI"),
                              _buildDropdown(),
                              _buildInputLabel("NOMOR PUNGGUNG"),
                              _buildTextField(_numberController,
                                  "Masukan nomor punggung...",
                                  keyboardType: TextInputType.number),
                              SizedBox(height: 10),
                              _buildButton("TAMBAH", _addPlayer),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(
                            top: 20, bottom: 40), // Moves it down/up
                        child: SizedBox(
                          height: 360,
                          child: VerticalDivider(
                            color: Color(0xFFCF7D03),
                            thickness: 4,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.only(
                              left: 16.0, top: 35), // Reduced top padding
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInputLabel("DAFTAR PEMAIN"),
                              Expanded(
                                child: MediaQuery.removePadding(
                                  removeTop: true,
                                  context: context,
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    itemCount: _players.length,
                                    itemBuilder: (context, index) {
                                      final player = _players[index];
                                      return ListTile(
                                        contentPadding: EdgeInsets.symmetric(
                                            vertical: 1.5,
                                            horizontal: 8), // Less padding
                                        dense: true, // Makes it more compact
                                        visualDensity: VisualDensity(
                                            vertical:
                                                -4), // Reduces vertical space
                                        title: Text(
                                          "${index + 1}. ${player['name']} (${player['position']}) No. Punggung: ${player['number']}",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize:
                                                15, // Slightly reduced size
                                          ),
                                        ),
                                        trailing: IconButton(
                                          icon: Icon(Icons.edit,
                                              color: Colors.white,
                                              size: 18), // Smaller icon
                                          onPressed: () =>
                                              _editPlayerDialog(context, index),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              SizedBox(height: 2),
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 16.0, bottom: 52.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    _buildResetButton("RESET", _resetPlayers),
                                    SizedBox(width: 12),
                                    _buildStartButton("MULAI"),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ));
  }

  Widget _buildInputLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0, bottom: 2.0),
      child: Text(text,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white)), // Adjust text color for visibility
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint,
      {TextInputType keyboardType = TextInputType.text}) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 2),
      height: 36,
      width: 380,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey),
        color: Colors.transparent,
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType, // Use the passed keyboard type
        decoration: InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(fontSize: 12),
          alignLabelWithHint: true,
        ),
        style: TextStyle(fontSize: 14),
      ),
    );
  }

  Widget _buildDropdown() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 2),
      height: 40,
      width: 380,
      padding: EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey),
        color: Colors.transparent, // Add opacity for better readability
      ),
      child: DropdownButton<String>(
        value: _selectedPosition,
        isExpanded: true,
        hint: Text("Pilih posisi", style: TextStyle(fontSize: 12)),
        underline: SizedBox(),
        onChanged: (String? newValue) {
          setState(() {
            _selectedPosition = newValue;
          });
        },
        items: ["Striker", "Tekong", "Feeder"].map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value, style: TextStyle(fontSize: 12)),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildButton(String text, VoidCallback? onPressed) {
    return SizedBox(
      width: 120,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: onPressed != null ? Colors.transparent : Colors.grey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Colors.white, // White border color
              width: 1.5, // Border width
            ),
          ),
        ),
        child: Text(text, style: TextStyle(fontSize: 14, color: Colors.white)),
      ),
    );
  }

  Widget _buildStartButton(String text) {
    return SizedBox(
      width: 120,
      child: ElevatedButton(
        onPressed: _players.length >= 3
            ? () {
                TextEditingController _opponentController =
                    TextEditingController();
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext context) {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return Center(
                          child: SingleChildScrollView(
                            // Scroll saat keyboard muncul tanpa menggeser dialog
                            child: AlertDialog(
                              title: Text("Masukkan Nama Tim Lawan"),
                              content: MediaQuery.removeViewInsets(
                                context: context,
                                removeBottom: true,
                                child: TextField(
                                  controller: _opponentController,
                                  decoration: InputDecoration(
                                    hintText: "Nama Tim Lawan",
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text("Cancel"),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    if (_opponentController.text.isNotEmpty) {
                                      Navigator.pop(context);
                                      _startGame(_opponentController.text);
                                    }
                                  },
                                  child: Text("Start"),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _players.length >= 3 ? Colors.green : Colors.grey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(text, style: TextStyle(fontSize: 14, color: Colors.white)),
      ),
    );
  }

  Widget _buildTextFieldWithoutUnderline(
      TextEditingController controller, String hintText) {
    return Container(
      height: 40,
      margin: EdgeInsets.symmetric(vertical: 2),
      padding: EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hintText,
          border: InputBorder.none, // Removes the underline
          contentPadding: EdgeInsets.symmetric(vertical: 4),
        ),
      ),
    );
  }

  Widget _buildResetButton(String text, VoidCallback? onPressed) {
    return SizedBox(
      width: 120,
      child: ElevatedButton(
        onPressed: onPressed != null
            ? () async {
                // Tampilkan pop-up konfirmasi.
                bool confirmed = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text("Konfirmasi Reset"),
                          content: Text(
                              "Apakah Anda yakin ingin mereset pemain dan poin?"),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop(false);
                              },
                              child: Text("Batal"),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop(true);
                              },
                              child: Text(
                                "Ya",
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        );
                      },
                    ) ??
                    false;
                if (confirmed) {
                  onPressed();
                }
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: onPressed != null ? Colors.red : Colors.grey,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(text, style: TextStyle(fontSize: 14, color: Colors.white)),
      ),
    );
  }
}

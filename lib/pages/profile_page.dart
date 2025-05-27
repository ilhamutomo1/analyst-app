import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Remove the AppBar if you want a custom design.
      body: Stack(
        children: [
          // Background image.
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/bgprofile.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Back button at top left.
          Positioned(
            top: 60, // Adjust top padding as needed
            left: 10, // Adjust left padding as needed
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          // Page content.
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                color: Colors.black.withOpacity(0.5), // Semi-transparent card
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 24.0, horizontal: 16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Default avatar using CircleAvatar with an Icon.

                      CircleAvatar(
                        radius: 80,
                        backgroundColor: Colors.white,
                        child: ClipOval(
                          child: SizedBox(
                            width: 160, // Diameter = 2 * radius
                            height: 160, // Diameter = 2 * radius
                            child: Image.asset(
                              'assets/profil.png',
                              fit: BoxFit
                                  .cover, // This ensures the image covers the entire area properly
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                      // Developer details
                      const Text(
                        "Muhammad Tegar Wilaksana",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "23060540042",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Prodi Ilmu Keolahragaan",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                      const Text(
                        "Fakultas Ilmu Keolahragaan dan Kesehatan",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                      const Text(
                        "Universitas Negeri Yogyakarta",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Aplikasinya Sepak Takraw Analysis Dibuat Sebagai Tugas Akhir Tesis",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

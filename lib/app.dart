import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:tidypics/core/permissions/gallery_permission.dart';
import 'package:tidypics/data/gallery_data.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool? permissionGranted;
  List<AssetEntity> photos = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initPermissions();
  }

  Future<void> _initPermissions() async {
    final granted = await checkAndRequestPermission();

    setState(() {
      permissionGranted = granted;
      isLoading = true;
    });

    if (granted) {
      print("Permission accordée ✅");
      final allPhotos = await getGalleryPhotos();
      setState(() {
        photos = allPhotos;
        isLoading = false;
      });
    } else {
      print("Permission refusée ❌");
      setState(() {
        isLoading = false;
      });
    }
  }

  AssetEntity getRandomPhoto() {
    if (photos.isEmpty) {
      throw Exception("No photos available");
    }

    final randomPhoto = (photos..shuffle()).first;
    return randomPhoto;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: _buildBody(),
    );
  }

  Widget? _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (permissionGranted == false) {
      return const Center(child: Text("Permission to access gallery denied."));
    }

    if (photos.isEmpty) {
      return const Center(child: Text("No photos found in the gallery."));
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Text(
            'Gallery Permission Status:',
          ),
          Text(
            permissionGranted == true ? 'Granted' : 'Not Granted',
          ),
          FutureBuilder(
            future: getRandomPhoto().file,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Text("Waiting for file to load..");
              }

              if (snapshot.hasError) {
                return Text("Error loading file: ${snapshot.error}");
              }

              final file = snapshot.data;
              if (file == null) {
                return const Text("No file available");
              }
              return Image.file(file);
            },
          )
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';

void main() => runApp(SmartBulbApp());

class SmartBulbApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, title: 'Smart Bulb', theme: ThemeData.dark(), home: BulbControlPage());
  }
}

class BulbControlPage extends StatefulWidget {
  @override
  _BulbControlPageState createState() => _BulbControlPageState();
}

class _BulbControlPageState extends State<BulbControlPage> {
  BluetoothConnection? connection;
  bool isConnected = false;
  bool isOn = false;
  double brightness = 0.5;
  Color selectedColor = Colors.white;
  List<BluetoothDevice> devices = [];

  @override
  void initState() { super.initState(); checkPermissions(); }

  Future<void> checkPermissions() async {
    await [Permission.bluetooth, Permission.bluetoothConnect, Permission.bluetoothScan, Permission.location].request();
    List<BluetoothDevice> bonded = await FlutterBluetoothSerial.instance.getBondedDevices();
    setState(() => devices = bonded);
  }

  Future<void> connect(BluetoothDevice device) async {
    try {
      connection = await BluetoothConnection.toAddress(device.address);
      setState(() => isConnected = true);
    } catch (e) {}
  }

  void sendData(String data) {
    if (connection!= null && connection!.isConnected) {
      connection!.output.add(Uint8List.fromList(data.codeUnits));
    }
  }

  void togglePower() { setState(() => isOn =!isOn); sendData(isOn? "ON\n" : "OFF\n"); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Smart Bulb'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          if (!isConnected)...[
            Text("Paired Devices:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Expanded(child: ListView.builder(itemCount: devices.length, itemBuilder: (c, i) => ListTile(title: Text(devices[i].name?? "Unknown"), subtitle: Text(devices[i].address), onTap: () => connect(devices[i])))),
          ] else...[
            Icon(Icons.lightbulb, size: 100, color: isOn? selectedColor : Colors.grey),
            SizedBox(height: 20),
            ElevatedButton(onPressed: togglePower, child: Text(isOn? "Turn OFF" : "Turn ON"), style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 60))),
            SizedBox(height: 20),
            Text("Brightness: ${(brightness * 100).toInt()}%"),
            Slider(value: brightness, onChanged: (v) { setState(() => brightness = v); sendData("B:${(v * 255).toInt()}\n"); }),
          ]
        ]),
      ),
    );
  }
}

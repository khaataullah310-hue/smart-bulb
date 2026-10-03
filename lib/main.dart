import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const SmartBulbApp());

class SmartBulbApp extends StatelessWidget {
  const SmartBulbApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const BulbHome(),
    );
  }
}

class BulbHome extends StatefulWidget {
  const BulbHome({super.key});
  @override
  State<BulbHome> createState() => _BulbHomeState();
}

class _BulbHomeState extends State<BulbHome> {
  BluetoothConnection? connection;
  List<BluetoothDevice> devices = [];
  bool isOn = false;
  double brightness = 100;
  Color currentColor = Colors.white;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  Future<void> _initBluetooth() async {
    // 1. بلیو ٹوتھ آن کرنے کی کوشش نہ کریں، صرف چیک کریں
    bool? isEnabled = await FlutterBluetoothSerial.instance.isEnabled;
    if (isEnabled == false) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please turn on Bluetooth from settings.')),
        );
      }
    }

    // 2. اجازتیں مانگیں
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();

    // 3. اگر اجازت مل گئی تو ڈیوائسز ڈھونڈیں
    if (statuses[Permission.location]!.isGranted || statuses[Permission.bluetoothConnect]!.isGranted) {
      List<BluetoothDevice> bonded = await FlutterBluetoothSerial.instance.getBondedDevices();
      if (mounted) {
        setState(() {
          devices = bonded;
          isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissions denied. Please allow them in settings.')),
        );
      }
    }
  }

  Future<void> _connect(BluetoothDevice device) async {
    try {
      connection = await BluetoothConnection.toAddress(device.address);
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  void _send(String cmd) {
    if (connection != null && connection!.isConnected) {
      connection!.output.add(Uint8List.fromList(cmd.codeUnits));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Bulb Controller'), centerTitle: true),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : connection == null
              ? devices.isEmpty
                  ? const Center(child: Text('No paired devices found.\nPlease pair a Bluetooth device first.'))
                  : ListView.builder(
                      itemCount: devices.length,
                      itemBuilder: (c, i) => ListTile(
                        leading: const Icon(Icons.lightbulb),
                        title: Text(devices[i].name ?? 'Unknown'),
                        subtitle: Text(devices[i].address),
                        onTap: () => _connect(devices[i]),
                      ),
                    )
              : Column(
                  children: [
                    const SizedBox(height: 30),
                    Icon(Icons.lightbulb, size: 120, color: isOn ? currentColor : Colors.grey),
                    SwitchListTile(
                      title: const Text('Bulb ON/OFF'),
                      value: isOn,
                      onChanged: (v) {
                        setState(() => isOn = v);
                        _send(v ? 'ON\n' : 'OFF\n');
                      },
                    ),
                    Slider(
                      value: brightness,
                      min: 0,
                      max: 100,
                      onChanged: (v) {
                        setState(() => brightness = v);
                        _send('B${v.toInt()}\n');
                      },
                    ),
                    Wrap(
                      spacing: 12,
                      children: [
                        Colors.red,
                        Colors.green,
                        Colors.blue,
                        Colors.white,
                        Colors.yellow,
                        Colors.purple
                      ]
                          .map((c) => GestureDetector(
                                onTap: () {
                                  setState(() => currentColor = c);
                                  _send('C${c.value}\n');
                                },
                                child: CircleAvatar(backgroundColor: c, radius: 22),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        connection?.close();
                        setState(() => connection = null);
                      },
                      child: const Text('Disconnect'),
                    )
                  ],
                ),
    );
  }
}

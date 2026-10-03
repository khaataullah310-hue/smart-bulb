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
  String statusText = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  Future<void> _initBluetooth() async {
    try {
      // Pehle permissions - alag alag
      await Permission.location.request();
      await Permission.bluetoothScan.request();
      await Permission.bluetoothConnect.request();
      await Permission.bluetooth.request();

      // Bluetooth ON hai?
      bool? isEnabled = await FlutterBluetoothSerial.instance.isEnabled
         ?.timeout(const Duration(seconds: 5), onTimeout: () => false);

      if (isEnabled == false) {
        if (!mounted) return;
        setState(() => statusText = 'Please turn on Bluetooth');
        await FlutterBluetoothSerial.instance.requestEnable();
      }

      List<BluetoothDevice> bonded = await FlutterBluetoothSerial.instance
         .getBondedDevices()
         .timeout(const Duration(seconds: 10), onTimeout: () => []);

      if (!mounted) return;
      setState(() {
        devices = bonded;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        statusText = 'Error: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bluetooth Error: $e')),
      );
    }
  }

  Future<void> _connect(BluetoothDevice device) async {
    setState(() => statusText = 'Connecting to ${device.name}...');
    try {
      connection = await BluetoothConnection.toAddress(device.address)
         .timeout(const Duration(seconds: 10));
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  void _send(String cmd) {
    if (connection!= null && connection!.isConnected) {
      connection!.output.add(Uint8List.fromList(cmd.codeUnits));
      connection!.output.allSent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Bulb Controller'), centerTitle: true),
      body: isLoading
         ? Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(statusText),
              ],
            ))
          : connection == null
             ? devices.isEmpty
                 ? Center(child: Text(statusText + '\n\nNo paired devices found.\nPlease pair bulb in phone Bluetooth settings first.', textAlign: TextAlign.center))
                  : ListView.builder(
                      itemCount: devices.length,
                      itemBuilder: (c, i) => ListTile(
                        leading: const Icon(Icons.lightbulb),
                        title: Text(devices[i].name?? 'Unknown'),
                        subtitle: Text(devices[i].address),
                        onTap: () => _connect(devices[i]),
                      ),
                    )
              : Column(
                  children: [
                    const SizedBox(height: 30),
                    Icon(Icons.lightbulb, size: 120, color: isOn? currentColor : Colors.grey),
                    SwitchListTile(
                      title: const Text('Bulb ON/OFF'),
                      value: isOn,
                      onChanged: (v) {
                        setState(() => isOn = v);
                        _send(v? 'ON\n' : 'OFF\n');
                      },
                    ),
                    Slider(
                      value: brightness,
                      min: 0,
                      max: 100,
                      label: brightness.toInt().toString(),
                      onChanged: (v) {
                        setState(() => brightness = v);
                        _send('B${v.toInt()}\n');
                      },
                    ),
                    Wrap(
                      spacing: 12,
                      children: [Colors.red, Colors.green, Colors.blue, Colors.white, Colors.yellow, Colors.purple]
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

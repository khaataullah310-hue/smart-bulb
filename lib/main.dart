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
  bool isLoading = true;

  // 6 بلب + 2 پنکھے کا State
  Map<String, bool> deviceStates = {
    'B1': false, 'B2': false, 'B3': false,
    'B4': false, 'B5': false, 'B6': false,
    'FAN': false, 'FAN2': false,
  };

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  Future<void> _initBluetooth() async {
    try {
      // Permission الگ الگ مانگنا - loading اٹکنے سے بچنے کے لیے
      await Permission.location.request();
      await Permission.bluetoothScan.request();
      await Permission.bluetoothConnect.request();

      List<BluetoothDevice> bonded = await FlutterBluetoothSerial.instance
         .getBondedDevices()
         .timeout(const Duration(seconds: 10), onTimeout: () => []);

      if (mounted) {
        setState(() {
          devices = bonded;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _connect(BluetoothDevice device) async {
    try {
      connection = await BluetoothConnection.toAddress(device.address)
         .timeout(const Duration(seconds: 10));
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connected to ${device.name}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  void _sendCommand(String cmd) {
    if (connection!= null && connection!.isConnected) {
      connection!.output.add(Uint8List.fromList('$cmd\n'.codeUnits));
      connection!.output.allSent;
    }
  }

  void _toggleDevice(String deviceKey) {
    setState(() {
      deviceStates[deviceKey] =!deviceStates[deviceKey]!;
    });
    _sendCommand(deviceStates[deviceKey]!? '${deviceKey}ON' : '${deviceKey}OFF');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('6 Bulb + Fan Controller'), centerTitle: true),
      body: isLoading
         ? const Center(child: CircularProgressIndicator())
          : connection == null
             ? devices.isEmpty
                 ? const Center(child: Text('No paired devices found.\nPair bulb in phone settings first.', textAlign: TextAlign.center))
                  : ListView.builder(
                      itemCount: devices.length,
                      itemBuilder: (c, i) => ListTile(
                        leading: const Icon(Icons.devices),
                        title: Text(devices[i].name?? 'Unknown'),
                        subtitle: Text(devices[i].address),
                        onTap: () => _connect(devices[i]),
                      ),
                    )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              _sendCommand('ALLON');
                              setState(() => deviceStates.updateAll((k, v) => true));
                            },
                            icon: const Icon(Icons.power_settings_new),
                            label: const Text('ALL ON'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          ),
                          const SizedBox(width: 20),
                          ElevatedButton.icon(
                            onPressed: () {
                              _sendCommand('ALLOFF');
                              setState(() => deviceStates.updateAll((k, v) => false));
                            },
                            icon: const Icon(Icons.power_off),
                            label: const Text('ALL OFF'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        padding: const EdgeInsets.all(10),
                        mainAxisSpacing: 15,
                        crossAxisSpacing: 15,
                        children: [
                          _buildDeviceCard('B1', 'Bulb 1', Icons.lightbulb),
                          _buildDeviceCard('B2', 'Bulb 2', Icons.lightbulb),
                          _buildDeviceCard('B3', 'Bulb 3', Icons.lightbulb),
                          _buildDeviceCard('B4', 'Bulb 4', Icons.lightbulb),
                          _buildDeviceCard('B5', 'Bulb 5', Icons.lightbulb),
                          _buildDeviceCard('B6', 'Bulb 6', Icons.lightbulb),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          children: [
                            Expanded(child: _buildFanCard('FAN', 'Fan 1')),
                            const SizedBox(width: 15),
                            Expanded(child: _buildFanCard('FAN2', 'Fan 2')),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          connection?.close();
                          setState(() => connection = null);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                        child: const Text('Disconnect'),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
    );
  }

  Widget _buildDeviceCard(String key, String title, IconData icon) {
    bool isOn = deviceStates[key]?? false;
    return Card(
      color: isOn? Colors.blueGrey[800] : Colors.grey[900],
      child: InkWell(
        onTap: () => _toggleDevice(key),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: isOn? Colors.yellow : Colors.grey),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text(isOn? 'ON' : 'OFF', style: TextStyle(fontSize: 16, color: isOn? Colors.green : Colors.red)),
          ],
        ),
      ),
    );
  }

  Widget _buildFanCard(String key, String title) {
    bool isOn = deviceStates[key]?? false;
    return Card(
      color: isOn? Colors.blueGrey[800] : Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            Icon(Icons.wind_power, size: 40, color: isOn? Colors.cyan : Colors.grey),
            const SizedBox(height: 5),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _speedButton('SLOW', Colors.green, '${key}SLOW', key),
                _speedButton('MED', Colors.orange, '${key}MED', key),
                _speedButton('FAST', Colors.red, '${key}FAST', key),
              ],
            ),
            const SizedBox(height: 5),
            TextButton(
              onPressed: () {
                setState(() => deviceStates[key] = false);
                _sendCommand('${key}OFF');
              },
              child: const Text('OFF', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _speedButton(String label, Color color, String command, String key) {
    return ElevatedButton(
      onPressed: () {
        setState(() => deviceStates[key] = true);
        _sendCommand(command);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        minimumSize: const Size(40, 30),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10)),
    );
  }
}

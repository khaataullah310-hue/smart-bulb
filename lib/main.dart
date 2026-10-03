Future<void> _initBluetooth() async {
  // 1. بلیو ٹوتھ کی حالت چیک کریں (خود آن کرنے کی کوشش نہ کریں)
  bool? isEnabled = await FlutterBluetoothSerial.instance.isEnabled;
  if (isEnabled == false) {
    // اگر بلیو ٹوتھ بند ہے تو میسج دکھائیں
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
        isLoading = false; // لوڈنگ ختم
      });
    }
  } else {
    // اگر اجازت نہ ملے تو میسج دکھائیں
    if (mounted) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissions denied. Please allow them in settings.')),
      );
    }
  }
}

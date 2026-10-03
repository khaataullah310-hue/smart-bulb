Future<void> _initBluetooth() async {
  // 1. بلیو ٹوتھ آن ہے یا نہیں چیک کریں
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

  // 3. اگر اجازتیں نہ ملیں تو سیٹنگز کھولیں
  if (statuses[Permission.location]!.isDenied ||
      statuses[Permission.bluetoothConnect]!.isDenied ||
      statuses[Permission.bluetoothScan]!.isDenied) {
    
    if (mounted) {
      setState(() => isLoading = false);
      // یہاں ہم ایپ کی سیٹنگز کھول رہے ہیں تاکہ آپ خود اجازت دے سکیں
      await openAppSettings();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please allow Nearby Devices and Location in settings.')),
      );
    }
    return;
  }

  // 4. اگر اجازت مل گئی تو ڈیوائسز ڈھونڈیں
  List<BluetoothDevice> bonded = await FlutterBluetoothSerial.instance.getBondedDevices();
  if (mounted) {
    setState(() {
      devices = bonded;
      isLoading = false;
    });
  }
}

import 'package:flutter/material.dart';
import 'graphs_page.dart';
import 'thermostat.dart';
import 'api_service.dart';

const textColor = Color(0xFFFFFFFD);

class ThermostatScreen extends StatefulWidget {
  const ThermostatScreen({super.key});

  @override
  State<ThermostatScreen> createState() => _ThermostatScreenState();
}

class _ThermostatScreenState extends State<ThermostatScreen> {
  static const _coolColor = Color(0xFF4EC4EC);

  double currentTemp = 27;
  double setTemp = 26;
  String acStatus = "IDLE";
  bool _turnOn = false;
  late ApiService apiService;
  String _connectionStatus = 'Connecting…';

  void updateLogic() {
    final diff = currentTemp - setTemp;
    if (diff.abs() <= 1) {
      acStatus = 'IDLE';
    } else if (diff > 1) {
      acStatus = 'Cooling';
    } else {
      acStatus = 'Heating';
    }
  }

  @override
  void initState() {
    super.initState();

    apiService = ApiService();
    apiService.onReadingReceived = (temp, humidity) {
      if (!mounted) return;
      setState(() {
        currentTemp = temp;
        updateLogic();
        if (_connectionStatus != 'Connected ✅') {
          _connectionStatus = 'Connected ✅';
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('API connected successfully!'),
              backgroundColor: Color(0xFF2ECC71),
              duration: Duration(seconds: 3),
            ),
          );
        }
      });
    };
    apiService.startPolling();
  }

  @override
  void dispose() {
    apiService.stopPolling();
    apiService.onReadingReceived = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(color: Color(0xFF0F2027)),
        child: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 70,
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      alignment: Alignment.center,
                      child: const Icon(Icons.keyboard_backspace, color: textColor),
                    ),
                    Container(
                      width: 1,
                      color: textColor,
                      margin: const EdgeInsets.only(left: 10, right: 10),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ThermoSmart',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _connectionStatus,
                            style: TextStyle(
                              color: _connectionStatus == 'Connected ✅'
                                  ? const Color(0xFF2ECC71)
                                  : const Color(0xFFE67E22),
                              fontSize: 10,
                            ),
                          ),
                          const Text(
                            'Kontes Room',
                            style: TextStyle(color: textColor, fontSize: 12),
                          ),
                          const SizedBox(height: 5),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.thermostat, color: Color(0xFFA9A6AF), size: 45),
                        Text(
                          '${currentTemp.toStringAsFixed(1)} C',
                          style: const TextStyle(color: _coolColor, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Center(
                  child: Thermostat(
                    radius: 150,
                    turnOn: _turnOn,
                    modeIcon: const Icon(Icons.loop, color: Colors.white),
                    textStyle: const TextStyle(color: textColor, fontSize: 34),
                    minValue: 18,
                    maxValue: 38,
                    initialValue: 26,
                    onValueChanged: (value) {
                      setState(() {
                        setTemp = value.toDouble();
                        updateLogic();
                      });
                      apiService.sendSetpoint(value.toDouble());
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                acStatus,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: acStatus == "IDLE"
                      ? const Color(0xFFA9A6AF)
                      : const Color(0xFF4EC4EC),
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 20),

              Container(height: 1, color: Colors.white.withOpacity(0.2)),

              Container(
                margin: const EdgeInsets.symmetric(vertical: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _BottomButton(
                      icon: Icon(
                        Icons.ac_unit,
                        color: _turnOn ? const Color(0xFF4EC4EC) : Colors.white,
                      ),
                      text: "Cooling",
                      onTap: () {
                        setState(() {
                          _turnOn = !_turnOn;
                        });
                      },
                    ),
                    const _BottomButton(
                      icon: Icon(Icons.invert_colors, color: Colors.white),
                      text: "Fan",
                    ),
                    _BottomButton(
                      icon: const Icon(Icons.bar_chart, color: Colors.white),
                      text: "Graphs",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const GraphsPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomButton extends StatelessWidget {
  final Widget icon;
  final String text;
  final VoidCallback? onTap;

  const _BottomButton({required this.icon, required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(height: 6),
          Text(text, style: const TextStyle(color: Color(0xFF7A8FA0), fontSize: 11)),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'graphs_page.dart';
import 'thermostat.dart';
import 'mqtt_service.dart';
import 'api_service.dart';

class ThermostatScreen extends StatefulWidget {
  const ThermostatScreen({super.key});

  @override
  State<ThermostatScreen> createState() => _ThermostatScreenState();
}

class _ThermostatScreenState extends State<ThermostatScreen> {
  static const _bg           = Color(0xFF0F2027);
  static const _textPrimary  = Color(0xFFFFFFFD);
  static const _textMuted    = Color(0xFF7A8FA0);
  static const _accent       = Color(0xFF3F5BFA);
  static const _coolColor    = Color(0xFF4EC4EC);
  static const _heatColor    = Color(0xFFFB923C);

  double currentTemp = 27;
  double currentHum  = 0;
  double setTemp     = 26;
  String acStatus    = 'IDLE';
  bool   _isHeating  = false;

  // Bağlantı durumları
  bool _mqttConnected = false;
  bool _apiConnected  = false;

  late MQTTService _mqttService;
  late ApiService  _apiService;

  // ─── Durum rengi ──────────────────────────────────────────────────────────

  Color get _statusColor {
    if (acStatus == 'IDLE')    return _textMuted;
    if (acStatus == 'Heating') return _heatColor;
    return _coolColor;
  }

  String get _connectionLabel {
    if (_mqttConnected && _apiConnected) return 'MQTT + API ✅';
    if (_mqttConnected)                  return 'MQTT ✅  API ⏳';
    if (_apiConnected)                   return 'API ✅  MQTT ⏳';
    return 'Bağlanıyor…';
  }

  Color get _connectionColor {
    if (_mqttConnected && _apiConnected) return const Color(0xFF2ECC71);
    if (_mqttConnected || _apiConnected) return const Color(0xFFE67E22);
    return const Color(0xFFE74C3C);
  }

  // ─── Logic ────────────────────────────────────────────────────────────────

  void _updateLogic() {
    final diff = currentTemp - setTemp;
    if (diff.abs() <= 1) {
      acStatus = 'IDLE';
    } else if (diff > 1) {
      acStatus = 'Cooling';
    } else {
      acStatus = 'Heating';
    }
  }

  // ─── initState ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _mqttService = MQTTService();
    _apiService  = ApiService();

    // ── MQTT ────────────────────────────────────────────────────────────────
    _mqttService.onConnectionChanged = (connected) {
      if (!mounted) return;
      setState(() => _mqttConnected = connected);
      if (connected) _showSnack('MQTT bağlandı ⚡', const Color(0xFF3B82F6));
    };

    // Real-time sıcaklık — MQTT öncelikli
    _mqttService.onTemperatureChanged = (temp) {
      if (!mounted) return;
      setState(() {
        currentTemp = temp;
        _updateLogic();
      });
    };

    _mqttService.onHumidityChanged = (hum) {
      if (!mounted) return;
      setState(() => currentHum = hum);
    };

    // ESP32'den heating durumu gelince UI güncelle
    _mqttService.onHeatingStateChanged = (state) {
      if (!mounted) return;
      setState(() => _isHeating = state == 'ON');
    };

    _mqttService.connect();

    // ── API ─────────────────────────────────────────────────────────────────
    // Yedek polling — MQTT kesilirse veri kaybı olmaz
    _apiService.onReadingReceived = (temp, humidity) {
      if (!mounted) return;
      if (_mqttConnected) return; // MQTT varsa API verisini görmezden gel
      setState(() {
        currentTemp = temp;
        currentHum  = humidity;
        _updateLogic();
        if (!_apiConnected) {
          _apiConnected = true;
          _showSnack('API bağlandı', const Color(0xFF2ECC71));
        }
      });
    };
    _apiService.startPolling(interval: const Duration(seconds: 10));
  }

  // ─── dispose ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _apiService.stopPolling();
    _apiService.onReadingReceived       = null;
    _mqttService.onTemperatureChanged   = null;
    _mqttService.onHumidityChanged      = null;
    _mqttService.onHeatingStateChanged  = null;
    _mqttService.onConnectionChanged    = null;
    super.dispose();
  }

  // ─── Setpoint gönder — HİBRİT ─────────────────────────────────────────────

  void _sendSetpoint(int value) {
    final sp = value.toDouble();
    setState(() {
      setTemp = sp;
      _updateLogic();
    });
    _mqttService.publishSetpoint(sp); // Anlık → ESP32
    _apiService.sendSetpoint(sp);     // Kalıcı → veritabanı
  }

  // ─── Helper ───────────────────────────────────────────────────────────────

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Column(
                children: [
                  _buildDialArea(),
                  _buildStatusPill(),
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFF1A2A36), thickness: 0.5, height: 1),
                  Expanded(child: _buildBottomArea()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1A2A36), width: 0.5)),
      ),
      child: Row(
        children: [
          _CircleButton(
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: _textPrimary, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ThermoSmart',
                  style: TextStyle(color: _textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
                ),
                // Bağlantı durumu göstergesi
                Row(
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        color: _connectionColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _connectionLabel,
                      style: TextStyle(color: _connectionColor, fontSize: 10),
                    ),
                  ],
                ),
                const Text(
                  'Kontes Room',
                  style: TextStyle(color: _textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          // Sağ: sıcaklık + nem
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _TempBadge(temp: currentTemp),
              if (currentHum > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    '💧 ${currentHum.toStringAsFixed(0)}%',
                    style: const TextStyle(color: _textMuted, fontSize: 10),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Dial ─────────────────────────────────────────────────────────────────

  Widget _buildDialArea() {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 10),
      child: Center(
        child: Thermostat(
          radius: 145,
          turnOn: true,
          modeIcon: Icon(
            Icons.loop_rounded,
            color: acStatus == 'IDLE' ? Colors.grey : Colors.green,
          ),
          textStyle: const TextStyle(color: _textPrimary, fontSize: 34),
          minValue: 15,
          maxValue: 35,
          initialValue: 26,
          onValueChanged: _sendSetpoint, // ← Hibrit gönderim
        ),
      ),
    );
  }

  // ─── Status pill ──────────────────────────────────────────────────────────

  Widget _buildStatusPill() {
    final isIdle    = acStatus == 'IDLE';
    final isCooling = acStatus == 'Cooling';
    final color  = isIdle ? _textMuted : isCooling ? _coolColor : _heatColor;
    final icon   = isIdle
        ? Icons.check_circle_outline_rounded
        : isCooling
            ? Icons.ac_unit_rounded
            : Icons.local_fire_department_rounded;
    final label  = isIdle ? 'IDLE' : isCooling ? 'Cooling' : 'Heating';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ─── Bottom area ──────────────────────────────────────────────────────────

  Widget _buildBottomArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildModeCards(),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildModeCards() {
    final isCooling = acStatus == 'Cooling';
    final isHeating = acStatus == 'Heating' || _isHeating;

    return Row(
      children: [
        Expanded(
          child: _ModeCard(
            icon: Icons.ac_unit_rounded,
            iconColor: _coolColor,
            label: 'Cooling',
            stateText: isCooling ? 'Active' : 'Standby',
            isActive: isCooling,
            activeColor: _coolColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ModeCard(
            icon: Icons.local_fire_department_rounded,
            iconColor: _heatColor,
            label: 'Heating',
            stateText: isHeating ? 'Active' : 'Standby',
            isActive: isHeating,
            activeColor: _heatColor,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.power_settings_new_rounded,
            label: 'Power',
            isPrimary: false,
            onTap: () => _mqttService.publishCommand('TOGGLE'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            icon: Icons.bar_chart_rounded,
            label: 'Graphs',
            isPrimary: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GraphsPage()),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            icon: Icons.settings_rounded,
            label: 'Settings',
            isPrimary: false,
            onTap: () {},
          ),
        ),
      ],
    );
  }
}

// ─── Reusable Widgets ─────────────────────────────────────────────────────────

class _CircleButton extends StatelessWidget {
  final Widget child;
  const _CircleButton({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34, height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF1E2E3A)),
      ),
      child: Center(child: child),
    );
  }
}

class _TempBadge extends StatelessWidget {
  final double temp;
  const _TempBadge({required this.temp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.thermostat_rounded, color: Color(0xFF7A8FA0), size: 14),
          const SizedBox(width: 4),
          Text(
            '${temp.toStringAsFixed(1)}°',
            style: const TextStyle(color: Color(0xFF4EC4EC), fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 3),
          const Text('current', style: TextStyle(color: Color(0xFF7A8FA0), fontSize: 10)),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   label;
  final String   stateText;
  final bool     isActive;
  final Color    activeColor;

  const _ModeCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.stateText,
    required this.isActive,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? activeColor.withOpacity(0.08) : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? activeColor.withOpacity(0.5) : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Color(0xFFFFFFFD), fontSize: 12, fontWeight: FontWeight.w500)),
              Text(stateText, style: TextStyle(color: isActive ? iconColor : const Color(0xFF7A8FA0), fontSize: 10)),
            ],
          ),
          const Spacer(),
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? activeColor : Colors.white.withOpacity(0.15),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData  icon;
  final String    label;
  final bool      isPrimary;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF3F5BFA);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isPrimary ? accent.withOpacity(0.1) : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPrimary ? accent.withOpacity(0.5) : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isPrimary ? const Color(0xFF7FA8FF) : Colors.white, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isPrimary ? const Color(0xFF7FA8FF) : const Color(0xFF7A8FA0),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
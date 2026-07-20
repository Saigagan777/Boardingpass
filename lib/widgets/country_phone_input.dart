import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CountryCode {
  final String name;
  final String dialCode;
  final String flag;
  final String code;

  const CountryCode({
    required this.name,
    required this.dialCode,
    required this.flag,
    required this.code,
  });
}

const List<CountryCode> defaultCountries = [
  CountryCode(name: 'India', dialCode: '+91', flag: '🇮🇳', code: 'IN'),
  CountryCode(name: 'United States', dialCode: '+1', flag: '🇺🇸', code: 'US'),
  CountryCode(name: 'United Kingdom', dialCode: '+44', flag: '🇬🇧', code: 'GB'),
  CountryCode(name: 'Canada', dialCode: '+1', flag: '🇨🇦', code: 'CA'),
  CountryCode(name: 'Australia', dialCode: '+61', flag: '🇦🇺', code: 'AU'),
  CountryCode(name: 'Germany', dialCode: '+49', flag: '🇩🇪', code: 'DE'),
  CountryCode(name: 'United Arab Emirates', dialCode: '+971', flag: '🇦🇪', code: 'AE'),
  CountryCode(name: 'Singapore', dialCode: '+65', flag: '🇸🇬', code: 'SG'),
  CountryCode(name: 'Japan', dialCode: '+81', flag: '🇯🇵', code: 'JP'),
  CountryCode(name: 'France', dialCode: '+33', flag: '🇫🇷', code: 'FR'),
  CountryCode(name: 'Saudi Arabia', dialCode: '+966', flag: '🇸🇦', code: 'SA'),
  CountryCode(name: 'Brazil', dialCode: '+55', flag: '🇧🇷', code: 'BR'),
];

class CountryPhoneInput extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final bool isRequired;
  final CountryCode initialCountry;
  final ValueChanged<CountryCode>? onCountryChanged;
  final String? Function(String?)? validator;
  final bool enabled;

  const CountryPhoneInput({
    super.key,
    required this.controller,
    this.label = 'Phone Number',
    this.hintText = 'Enter 10-digit number',
    this.isRequired = true,
    this.initialCountry = const CountryCode(
      name: 'India',
      dialCode: '+91',
      flag: '🇮🇳',
      code: 'IN',
    ),
    this.onCountryChanged,
    this.validator,
    this.enabled = true,
  });

  @override
  State<CountryPhoneInput> createState() => _CountryPhoneInputState();
}

class _CountryPhoneInputState extends State<CountryPhoneInput> {
  late CountryCode _selectedCountry;

  @override
  void initState() {
    super.initState();
    _selectedCountry = widget.initialCountry;
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Select Country',
                style: TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3E1F11),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: defaultCountries.length,
                  itemBuilder: (context, index) {
                    final country = defaultCountries[index];
                    final isSelected = country.dialCode == _selectedCountry.dialCode &&
                        country.code == _selectedCountry.code;
                    return ListTile(
                      leading: Text(
                        country.flag,
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(
                        country.name,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF3E1F11),
                        ),
                      ),
                      trailing: Text(
                        country.dialCode,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? const Color(0xFF7A432D) : const Color(0xFF8C736B),
                        ),
                      ),
                      selected: isSelected,
                      onTap: () {
                        setState(() {
                          _selectedCountry = country;
                        });
                        if (widget.onCountryChanged != null) {
                          widget.onCountryChanged!(country);
                        }
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Country Code Selector Button
            InkWell(
              onTap: widget.enabled ? _showCountryPicker : null,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE8E2DD)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedCountry.flag,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _selectedCountry.dialCode,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3E1F11),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_drop_down,
                      color: Color(0xFF7A432D),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Phone Number Form Field
            Expanded(
              child: TextFormField(
                controller: widget.controller,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: InputDecoration(
                  label: widget.isRequired
                      ? Text.rich(
                          TextSpan(
                            text: widget.label,
                            children: const [
                              TextSpan(
                                text: ' *',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        )
                      : Text(widget.label),
                  hintText: widget.hintText,
                  hintStyle: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    color: Color(0xFFB0A29C),
                    fontSize: 13,
                  ),
                  labelStyle: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    color: Color(0xFF8C736B),
                    fontSize: 13,
                  ),
                  floatingLabelStyle: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    color: Color(0xFF7A432D),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE8E2DD)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE8E2DD)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF7A432D), width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFC62828)),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFC62828), width: 1.5),
                  ),
                ),
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  color: Color(0xFF3E1F11),
                ),
                validator: widget.validator ??
                    (value) {
                      final val = value?.trim() ?? '';
                      if (widget.isRequired && val.isEmpty) {
                        return 'Phone number is required';
                      }
                      if (val.isNotEmpty) {
                        if (!RegExp(r'^\d+$').hasMatch(val)) {
                          return 'Only digits (0-9) are allowed';
                        }
                        if (val.length != 10) {
                          return 'Phone number must be exactly 10 digits';
                        }
                      }
                      return null;
                    },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

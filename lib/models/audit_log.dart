import 'package:flutter/material.dart';

class AuditLog {
  final int? id;
  final String userName;
  final String userEmail;
  final String category; // 'SECURITY', 'VALVE_CONTROL', 'SETTINGS', 'SAFETY_ALERT', 'SYSTEM'
  final String action;
  final String details;
  final String ipAddress;
  final DateTime timestamp;

  AuditLog({
    this.id,
    required this.userName,
    required this.userEmail,
    required this.category,
    required this.action,
    required this.details,
    required this.ipAddress,
    required this.timestamp,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      userName: json['user_name'] ?? 'System',
      userEmail: json['user_email'] ?? 'system@danum.local',
      category: json['category'] ?? 'SYSTEM',
      action: json['action'] ?? 'Unknown Action',
      details: json['details'] ?? '',
      ipAddress: json['ip_address'] ?? '127.0.0.1',
      timestamp: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_name': userName,
      'user_email': userEmail,
      'category': category,
      'action': action,
      'details': details,
      'ip_address': ipAddress,
      'created_at': timestamp.toIso8601String(),
    };
  }

  IconData get categoryIcon {
    switch (category.toUpperCase()) {
      case 'SECURITY':
        return Icons.security_rounded;
      case 'VALVE_CONTROL':
        return Icons.water_drop_rounded;
      case 'SETTINGS':
        return Icons.tune_rounded;
      case 'SAFETY_ALERT':
        return Icons.warning_amber_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Color get categoryColor {
    switch (category.toUpperCase()) {
      case 'SECURITY':
        return Colors.blueAccent;
      case 'VALVE_CONTROL':
        return Colors.cyanAccent;
      case 'SETTINGS':
        return Colors.orangeAccent;
      case 'SAFETY_ALERT':
        return Colors.redAccent;
      default:
        return Colors.purpleAccent;
    }
  }
}

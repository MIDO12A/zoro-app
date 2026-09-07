import 'package:flutter/material.dart';

/// نموذج بيانات وكيل المضيفين (AgentInfoBean)
class AgentInfoModel {
  final int userId;
  final int agentBean;
  final int agentGold;
  final int beanNumber;
  final int transferBean;
  final int transferBeanDollar;
  final int transferDollar;
  final int transferMoney;
  final int transferNumber;
  final String agencyName;
  final String avatarUrl;
  final String countryFlagUrl;

  const AgentInfoModel({
    this.userId = 0,
    this.agentBean = 0,
    this.agentGold = 0,
    this.beanNumber = 0,
    this.transferBean = 0,
    this.transferBeanDollar = 0,
    this.transferDollar = 0,
    this.transferMoney = 0,
    this.transferNumber = 0,
    this.agencyName = '',
    this.avatarUrl = '',
    this.countryFlagUrl = '',
  });

  factory AgentInfoModel.fromJson(Map<String, dynamic> json) {
    return AgentInfoModel(
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      agentBean: (json['agent_bean'] as num?)?.toInt() ?? 0,
      agentGold: (json['agent_gold'] as num?)?.toInt() ?? 0,
      beanNumber: (json['bean_number'] as num?)?.toInt() ?? 0,
      transferBean: (json['transfer_bean'] as num?)?.toInt() ?? 0,
      transferBeanDollar: (json['transfer_bean_dollar'] as num?)?.toInt() ?? 0,
      transferDollar: (json['transfer_dollar'] as num?)?.toInt() ?? 0,
      transferMoney: (json['transfer_money'] as num?)?.toInt() ?? 0,
      transferNumber: (json['transfer_number'] as num?)?.toInt() ?? 0,
      agencyName: json['agency_name']?.toString() ?? json['nickname']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString() ?? json['headImage']?.toString() ?? '',
      countryFlagUrl: json['country_flag_url']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'agent_bean': agentBean,
        'agent_gold': agentGold,
        'bean_number': beanNumber,
        'transfer_bean': transferBean,
        'transfer_bean_dollar': transferBeanDollar,
        'transfer_dollar': transferDollar,
        'transfer_money': transferMoney,
        'transfer_number': transferNumber,
        'agency_name': agencyName,
        'avatar_url': avatarUrl,
        'country_flag_url': countryFlagUrl,
      };
}

/// نموذج معلومات المضيف التابع للوكالة (AnchorAgentUserInfoDataBean)
class AnchorAgentUserInfoDataModel {
  final int userId;
  final int userNo;
  final String nickname;
  final String headImage;
  final int country;
  final String countryFlagUrl;
  final int days;
  final double minute;
  final String diamonds;
  final int experience;
  final int level;
  final int recgLevel;
  final int rechargeValue;
  final int sex;
  final int vip;
  final int targetDiamonds;

  const AnchorAgentUserInfoDataModel({
    this.userId = 0,
    this.userNo = 0,
    this.nickname = '',
    this.headImage = '',
    this.country = 0,
    this.countryFlagUrl = '',
    this.days = 0,
    this.minute = 0.0,
    this.diamonds = '0',
    this.experience = 0,
    this.level = 1,
    this.recgLevel = 0,
    this.rechargeValue = 0,
    this.sex = 1,
    this.vip = 0,
    this.targetDiamonds = 100000,
  });

  String get formattedTime {
    final totalHours = (minute / 60).toStringAsFixed(1);
    return '$days أيام / $totalHours ساعة';
  }

  double get targetProgress {
    final current = double.tryParse(diamonds) ?? 0.0;
    if (targetDiamonds <= 0) return 0.0;
    return (current / targetDiamonds).clamp(0.0, 1.0);
  }

  factory AnchorAgentUserInfoDataModel.fromJson(Map<String, dynamic> json) {
    return AnchorAgentUserInfoDataModel(
      userId: (json['user_id'] as num?)?.toInt() ?? (json['uid'] != null ? int.tryParse(json['uid'].toString()) ?? 0 : 0),
      userNo: (json['user_no'] as num?)?.toInt() ?? (json['custom_id'] != null ? int.tryParse(json['custom_id'].toString()) ?? 0 : 0),
      nickname: json['nickname']?.toString() ?? json['name']?.toString() ?? '',
      headImage: json['headImage']?.toString() ?? json['photo_url']?.toString() ?? json['avatar']?.toString() ?? '',
      country: (json['country'] as num?)?.toInt() ?? 0,
      countryFlagUrl: json['country_flag_url']?.toString() ?? '',
      days: (json['days'] as num?)?.toInt() ?? 0,
      minute: (json['minute'] as num?)?.toDouble() ?? 0.0,
      diamonds: json['diamonds']?.toString() ?? json['earnings']?.toString() ?? '0',
      experience: (json['experience'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
      recgLevel: (json['recg_level'] as num?)?.toInt() ?? 0,
      rechargeValue: (json['recharge_value'] as num?)?.toInt() ?? 0,
      sex: (json['sex'] as num?)?.toInt() ?? 1,
      vip: (json['vip'] as num?)?.toInt() ?? 0,
      targetDiamonds: (json['target_diamonds'] as num?)?.toInt() ?? 100000,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'user_no': userNo,
        'nickname': nickname,
        'headImage': headImage,
        'country': country,
        'country_flag_url': countryFlagUrl,
        'days': days,
        'minute': minute,
        'diamonds': diamonds,
        'experience': experience,
        'level': level,
        'recg_level': recgLevel,
        'recharge_value': rechargeValue,
        'sex': sex,
        'vip': vip,
        'target_diamonds': targetDiamonds,
      };
}

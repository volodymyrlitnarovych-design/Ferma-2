
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SaveData {
  int money; double fuel;
  Map<String,int> cropStore; // harvested goods
  Map<String,int> seeds; // seed amounts by crop
  String characterColor; String language; double dayLength;
  SaveData({required this.money, required this.fuel, required this.cropStore, required this.seeds, required this.characterColor, required this.language, required this.dayLength});
  Map<String, dynamic> toJson() => {
    'money':money,'fuel':fuel,'cropStore':cropStore,'seeds':seeds,'characterColor':characterColor,'language':language,'dayLength':dayLength
  };
  static SaveData fromJson(Map<String,dynamic> j)=>SaveData(
    money: j['money']??10000,
    fuel: (j['fuel']??100).toDouble(),
    cropStore: Map<String,int>.from(j['cropStore']??{}),
    seeds: Map<String,int>.from(j['seeds']??{}),
    characterColor: j['characterColor']??'green',
    language: j['language']??'uk',
    dayLength: (j['dayLength']??120.0).toDouble(),
  );
}

class SaveSystem {
  static const _key = 'open_farm_save_v2';
  static Future<void> save(SaveData d) async { final p=await SharedPreferences.getInstance(); await p.setString(_key, jsonEncode(d.toJson())); }
  static Future<SaveData?> load() async { final p=await SharedPreferences.getInstance(); final s=p.getString(_key); if(s==null) return null; return SaveData.fromJson(jsonDecode(s)); }
  static Future<void> reset() async { final p=await SharedPreferences.getInstance(); await p.remove(_key); }
}

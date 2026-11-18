import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const plum = Color(0xFF613348),
    coral = Color(0xFFD86B93),
    cream = Color(0xFFFFF8FA);
const lilac = Color(0xFFF9E4EC),
    sage = Color(0xFF71856A),
    inkSoft = Color(0xFF806674);
const url = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://dtjasplpglevmtagkrfp.supabase.co',
);
const key = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: 'sb_publishable_q3BBWv0BmSRnwApM7YH99w_5gHQV7KF',
);
SupabaseClient get db => Supabase.instance.client;
const authRedirectUrl = 'com.sanjaya.jigu://login-callback';

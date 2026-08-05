import 'package:flutter/material.dart';

/// One selectable item inside a category, e.g. "🪪 Driving License Renewal".
class CategoryItem {
  const CategoryItem(this.emoji, this.label);
  final String emoji;
  final String label;
}

/// A category header (e.g. "Insurance") and the items under it.
class Category {
  const Category({
    required this.name,
    required this.icon,
    required this.color,
    required this.items,
    this.custom = false,
  });

  final String name;
  final IconData icon;
  final Color color;
  final List<CategoryItem> items;

  /// True for user-created categories (vs the built-in catalog below).
  final bool custom;
}

/// The built-in catalog — the exact headers and items the app ships with.
/// Users can add their own categories on top of these.
const List<Category> kCatalog = [
  Category(
    name: 'Identity & Government',
    icon: Icons.badge_outlined,
    color: Color(0xFF4F46E5),
    items: [
      CategoryItem('🪪', 'Driving License Renewal'),
      CategoryItem('🛂', 'Passport Renewal'),
      CategoryItem('🆔', 'National ID Renewal'),
      CategoryItem('🗳️', 'Voter ID Update'),
      CategoryItem('🚗', 'Vehicle Registration Renewal'),
      CategoryItem('🌍', 'Visa Renewal'),
      CategoryItem('👮', 'Police Clearance Renewal'),
    ],
  ),
  Category(
    name: 'Vehicle',
    icon: Icons.directions_car_outlined,
    color: Color(0xFF0EA5E9),
    items: [
      CategoryItem('🚘', 'Car Insurance Renewal'),
      CategoryItem('🏍️', 'Bike Insurance Renewal'),
      CategoryItem('🔧', 'Vehicle Service Due'),
      CategoryItem('🛞', 'Tire Replacement'),
      CategoryItem('🛢️', 'Engine Oil Change'),
      CategoryItem('🔋', 'Battery Replacement'),
      CategoryItem('🚦', 'Pollution Certificate Renewal'),
    ],
  ),
  Category(
    name: 'Insurance',
    icon: Icons.shield_outlined,
    color: Color(0xFF16A34A),
    items: [
      CategoryItem('❤️', 'Life Insurance Premium (LIC)'),
      CategoryItem('🏥', 'Health Insurance Premium'),
      CategoryItem('🏠', 'Home Insurance Renewal'),
      CategoryItem('🧳', 'Travel Insurance Renewal'),
      CategoryItem('💼', 'Personal Accident Insurance'),
    ],
  ),
  Category(
    name: 'Banking & Finance',
    icon: Icons.account_balance_outlined,
    color: Color(0xFFCA8A04),
    items: [
      CategoryItem('💳', 'Credit Card Bill Due'),
      CategoryItem('🏦', 'Loan EMI Due'),
      CategoryItem('🏠', 'Home Loan EMI'),
      CategoryItem('🚗', 'Car Loan EMI'),
      CategoryItem('💸', 'SIP Investment Date'),
      CategoryItem('📈', 'Mutual Fund Review'),
      CategoryItem('📊', 'Stock Portfolio Review'),
      CategoryItem('💵', 'Fixed Deposit Maturity'),
      CategoryItem('💰', 'Recurring Deposit Maturity'),
      CategoryItem('📄', 'Income Tax Filing'),
      CategoryItem('🧾', 'Property Tax Due'),
    ],
  ),
  Category(
    name: 'Utilities',
    icon: Icons.bolt_outlined,
    color: Color(0xFFF59E0B),
    items: [
      CategoryItem('💡', 'Electricity Bill'),
      CategoryItem('💧', 'Water Bill'),
      CategoryItem('🔥', 'Gas Bill'),
      CategoryItem('🌐', 'Internet Bill'),
      CategoryItem('📱', 'Mobile Recharge'),
      CategoryItem('📺', 'DTH/Cable Renewal'),
    ],
  ),
  Category(
    name: 'Health',
    icon: Icons.favorite_outline,
    color: Color(0xFFEF4444),
    items: [
      CategoryItem('💊', 'Medicine Refill'),
      CategoryItem('👨‍⚕️', 'Annual Health Check-up'),
      CategoryItem('🦷', 'Dental Check-up'),
      CategoryItem('👓', 'Eye Check-up'),
      CategoryItem('💉', 'Vaccination Due'),
    ],
  ),
  Category(
    name: 'Home',
    icon: Icons.home_outlined,
    color: Color(0xFF9333EA),
    items: [
      CategoryItem('🧹', 'Deep House Cleaning'),
      CategoryItem('❄️', 'AC Service'),
      CategoryItem('💧', 'Water Purifier Filter Change'),
      CategoryItem('🔥', 'Fire Extinguisher Service'),
      CategoryItem('🐜', 'Pest Control'),
    ],
  ),
  Category(
    name: 'Family & Personal',
    icon: Icons.people_outline,
    color: Color(0xFFEC4899),
    items: [
      CategoryItem('🎂', 'Birthday'),
      CategoryItem('💍', 'Wedding Anniversary'),
      CategoryItem('🎓', 'School Fee Payment'),
      CategoryItem('👨‍🏫', 'Parent-Teacher Meeting'),
      CategoryItem('🎁', 'Festival Preparation'),
    ],
  ),
  Category(
    name: 'Digital',
    icon: Icons.devices_outlined,
    color: Color(0xFF06B6D4),
    items: [
      CategoryItem('🔐', 'Change Passwords'),
      CategoryItem('☁️', 'Cloud Backup'),
      CategoryItem('💻', 'Laptop Backup'),
      CategoryItem('💽', 'Software Subscription Renewal'),
      CategoryItem('🎬', 'OTT Subscription Renewal'),
    ],
  ),
];

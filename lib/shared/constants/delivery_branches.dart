/// The branches a forwarded parcel can be delivered to.
///
/// The address book stores the branch as a code (`branchCode`), so the app owns
/// the code ↔ display-name mapping. Codes are ASCII so they survive a round
/// trip through the backend unchanged; the names are what the customer picks
/// from in the send flow.
class DeliveryBranch {
  const DeliveryBranch({required this.code, required this.name});

  final String code;
  final String name;
}

const List<DeliveryBranch> kDeliveryBranches = [
  DeliveryBranch(code: 'ANOUSITH', name: 'ອານຸສິດ'),
];

const List<String> kDeliveryBranchNames = [
  'ອານຸສິດ',
];

/// Display name for a stored code, or null when the code is unknown — a branch
/// the backend knows about but this build does not must not silently become a
/// different branch.
String? deliveryBranchNameOf(String? code) {
  if (code == null || code.isEmpty) {
    return null;
  }
  for (final branch in kDeliveryBranches) {
    if (branch.code == code) {
      return branch.name;
    }
  }
  return null;
}

/// Code for a display name, or null when the name is not one of the branches.
String? deliveryBranchCodeOf(String? name) {
  if (name == null || name.isEmpty) {
    return null;
  }
  for (final branch in kDeliveryBranches) {
    if (branch.name == name) {
      return branch.code;
    }
  }
  return null;
}

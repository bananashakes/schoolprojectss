class Validation {
  // checks if the email field is empty or invalid
  static String? email(String? value) {
    // makes sure the user typed something
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email.';
    }

    // regex is a pattern used to check if the email looks valid
    // ^ means the check starts from the beginning of the text
    // [\w-\.]+ means the email name can contain letters, numbers, underscore, dash, or dot
    // @ means the email must contain the @ symbol
    // ([\w-]+\.)+ means the domain must have words followed by a dot, like gmail.
    // [\w-]{2,63} means the ending can be 2 to 63 characters, which covers longer domains like edu.sg or technology
    // $ means the check must end here, so extra invalid text is not allowed
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,63}$');

    // checks the email entered against the regex pattern
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address.';
    }

    // returns null when there is no error
    return null;
  }

  // checks if the password field is empty or too short
  static String? password(String? value) {
    // makes sure the user typed something
    if (value == null || value.isEmpty) {
      return 'Please enter your password.';
    }

    // firebase password usually needs at least 6 characters
    if (value.length < 6) {
      return 'Password must be at least 6 characters.';
    }

    // returns null when there is no error
    return null;
  }
}

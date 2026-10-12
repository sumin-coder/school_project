class UserCredentials {
  String email;
  String password;

  UserCredentials({
    this.email = '',
    this.password = '',
  });

  bool get isValid => email.contains('@') && password.length >= 6;
}
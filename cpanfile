requires "Authen::SASL" => "0";
requires "Data::Object" => "0.17";
requires "Email::AddressParser" => "0";
requires "Email::Stuffer" => "0";
requires "File::Slurp" => "0";
requires "IO::Socket::SSL" => "0";
requires "Net::SMTP::SSL" => "0";
requires "Net::SMTP::TLS" => "0";
requires "Net::SSLeay" => "0";
requires "perl" => "v5.10.0";

on 'test' => sub {
  requires "perl" => "v5.10.0";
};

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "0";
};

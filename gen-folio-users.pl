#!/usr/bin/perl
# build a users collection with fake data
use strict;
use warnings;
use Data::Faker;
use UUID::Tiny qw(:std);
use Date::Calc qw(Add_Delta_Days);
use JSON;
use Getopt::Long;

# Command line options --users --start --group --addresstype --servicepoint
# --group, --addresstype, --servicepoint can be specified multiple times, or comma delimited
# If --addresstype is not provided, use legacy addressTypeId
my $users = 20;
my $start = 0;
my @groups = ();
my @address_types = ();
my @service_points = ();
GetOptions (
            "users=i" => \$users,
            "start=i" => \$start,
            "group=s" => \@groups,
            "addresstype:s" => \@address_types,
            "servicepoint=s" => \@service_points
           );
@groups = split(/,/,join(',',@groups));
@address_types = split(/,/,join(',',@address_types));
@service_points = split(/,/,join(',',@service_points));

my $faker = Data::Faker->new();
my $common_last_name = $faker->last_name();
my ($day,$month,$year) = (localtime(time))[3..5];
$year += 1900;
$month += 1;
my %usernames;
my %barcodes;

# possible values for contactTypeId:
# 001 = Mail
# 002 = Email
# 003 = Text message
# 004 = Phone
# 005 = Mobile phone
my @contacts = qw(001 002 003 004 005);

# possible values for addressTypeId
# 001 = Claim
# 002 = Home
# 003 = Order
# 004 = Payment
# 005 = Returns
# 006 = Work
unless (@address_types) {
  @address_types = qw(002 006);
}

for (my $i = $start; $i < $users + $start; $i++) {
  my $id = create_uuid_as_string(UUID_V4);
  my $username = $faker->username();
  until (!$usernames{$username}) {
    $username = $faker->username();
  }
  $usernames{$username} = 1;
  my $barcode = sprintf("%d",rand(1e+15));
  until (!$barcodes{$barcode}) {
    $barcode = sprintf("%d",rand(1e+15));
  }
  my ($enr_year,$enr_month,$enr_day) = Add_Delta_Days($year,$month,$day,-int(rand(1460)));
  my ($exp_year,$exp_month,$exp_day) = Add_Delta_Days($year,$month,$day,int(rand(730)));
  my ($birth_year,$birth_month,$birth_day) = Add_Delta_Days($enr_year,$enr_month,$enr_day,-(int(rand(25550)) + 730));
  $barcodes{$barcode} = 1;
  my $user = {
              username => $username,
              id => $id,
              barcode => $barcode,
              active => (rand(1) > 0.3 ? JSON::true : JSON::false),
              type => 'patron',
              personal => {
                           lastName => $faker->last_name(),
                           firstName => $faker->first_name(),
                           email => $faker->email(),
                           phone => $faker->phone_number(),
                           dateOfBirth => "$birth_year-" . sprintf("%02d",$birth_month) . '-' . sprintf("%02d",$birth_day),
                           preferredContactTypeId => $contacts[int(rand(5))],
                           addresses => [
                                         {
                                          countryId => 'US',
                                          addressLine1 => $faker->street_address(),
                                          city => $faker->city(),
                                          region => $faker->us_state_abbr(),
                                          postalCode => $faker->us_zip_code(),
                                          addressTypeId => $address_types[int(rand(@address_types))],
                                          primaryAddress => JSON::true
                                         }
                                        ]
                          },
              enrollmentDate => "$enr_year-" . sprintf("%02d",$enr_month) . '-' . sprintf("%02d",$enr_day),
              expirationDate => "$exp_year-" . sprintf("%02d",$exp_month) . '-' . sprintf("%02d",$exp_day)
             };
  if (@groups) {
    $$user{'patronGroup'} = $groups[rand(@groups)];
  }
  if (rand(1) > 0.3) {
    $$user{'personal'}{'middleName'} = $faker->first_name();
  }
  if (rand(1) > 0.3) {
    $$user{'personal'}{'mobilePhone'} = $faker->phone_number();
  }
  my $login_user = {
                    username => $$user{username},
                    password => $$user{username}
                   };
  my $perms_user = { userId => $id };
  my $service_points_user = {
                             userId => $id,
                             servicePointsIds => \@service_points,
                             defaultServicePointId => $service_points[int(rand(@service_points))]
                            };
  open(USER,">sample-data/users/User" . sprintf("%03d",$i) . ".json") or die "Can't open output file: $!\n";
  print USER to_json($user, { pretty => 1 }) . "\n";
  close(USER);

  open(LOGIN,">sample-data/authn/credentials/User" . sprintf("%03d",$i) . ".json") or die "Can't open output file: $!\n";
  print LOGIN to_json($login_user, { pretty => 1 }) . "\n";
  close(LOGIN);

  open(PERMS,">sample-data/perms/users/User" . sprintf("%03d",$i) . ".json") or die "Can't open output file: $!\n";
  print PERMS to_json($perms_user, { pretty => 1 }) . "\n";
  close(PERMS);

  open(SP,">sample-data/service-points-users/User" . sprintf("%03d",$i) . ".json") or die "Can't open output file: $!\n";
  print SP to_json($service_points_user, { pretty => 1 }) . "\n";
  close(SP);
}

exit;


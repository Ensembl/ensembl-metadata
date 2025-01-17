#!/usr/bin/env perl
# Copyright [2016-2025] EMBL-European Bioinformatics Institute
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

=head1 DESCRIPTION

This script sets the 'packed' status, which is used in web display.

=head1 OPTIONS

=over 8

=item B<-host> <host>

=item B<-port> <port>

=item B<-user> <user>

=item B<-pass[word]> <password>

=item B<-db[name]> <dbname>

Mandatory. Connection details, e.g. $(meta1 details script) -db ensembl_metadata

=item B<-n[ame]> <name>

Mandatory. Production name of the species to update, e.g. choloepus_didactylus_gca015220235v1

=item B<-e[nsembl_release]> <ensembl_release>

Ensembl release version

=item B<-s[econdary_release]> <secondary_release>

Ensembl Genomes or Rapid Release version

=item B<-p[acked]> <packed>

Packed status to set: 0 or 1 (default 1)

=back

=cut

use warnings;
use strict;
use feature 'say';

use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage;

use Bio::EnsEMBL::MetaData::DBSQL::MetaDataDBAdaptor;

my ($help,
    $host, $port, $user, $pass, $dbname,
    $name, $ensembl_release, $secondary_release, $packed);

GetOptions(
  "h|help!",             \$help,
  "host=s",              \$host,
  "port=i",              \$port,
  "user=s",              \$user,
  "password:s",          \$pass,
  "dbname=s",            \$dbname,
  "name=s",              \$name,
  "ensembl_release:s",   \$ensembl_release,
  "secondary_release:s", \$secondary_release,
  "p|packed:i",          \$packed,
);

pod2usage(1) if $help;

if (! defined $name) {
  say('-name is a mandatory parameter');
  pod2usage(1);
}

$packed = 1 unless defined $packed;

my $mdba = Bio::EnsEMBL::MetaData::DBSQL::MetaDataDBAdaptor->new(
  -host    => $host,
  -port    => $port,
  -user    => $user,
  -pass    => $pass,
  -dbname  => $dbname,
  -species => 'multi',
  -group   => 'metadata',
);

if (! defined $mdba) {
  say('Unable to connect to metadata database with given parameters');
  pod2usage(1);
}

my $gia  = $mdba->get_GenomeInfoAdaptor();

if (defined $secondary_release) {
  $gia->set_ensembl_genomes_release($secondary_release);
} elsif (defined $ensembl_release) {
  $gia->set_ensembl_release($ensembl_release);
}

foreach ( @{ $gia->fetch_by_name($name) } ) {
  $gia->update_website_packed($_, $packed);
}

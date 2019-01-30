#!/usr/bin/env perl
# Copyright [2009-2019] EMBL-European Bioinformatics Institute
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



=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 DESCRIPTION

This script is used to retrieve the list of genomes for a given division and release

=head1 SYNOPSIS

perl get_list_genomes_for_division.pl $(mysql-ens-meta-prod-1 details script) \
   -release 95 -division vertebrates

perl get_list_genomes_for_division.pl $(mysql-ens-meta-prod-1 details script) \
   -release 42 -division metazoa

=head1 OPTIONS

=over 8

=item B<-h[ost]> <host>

Mandatory. Host name of the metadata server

=item B<-n[ame]> <ensembl_metadata>

Mandatory. metadata database name, default "ensembl_metadata"

=item B<-p[ort]> <port>

Mandatory. Port number of the metadata server

=item B<-p[assword]> <password>

Password of the metadata server

=item B<-di[vision]> [EnsemblVertebrates|vertebrates|EnsemblBacteria|bacteria|EnsemblFungi|fungi|EnsemblPlants|plants|EnsemblProtists|protists|EnsemblMetazoa|metazoa]

Name of the division.
If not defined, it will dump all the non-verbetrates species if release is specified

=item B<-r[elease]> <release>

Release number of the vertebrates or non-vertebrates release
If not defined, the script will get the current release if division is specified

=item B<-h[elp]>

Print usage information.

=item B<-m[man]>

Print full usage information.

=back

=head1 AUTHOR

tmaurel

=head1 MAINTANER

tmaurel

=head1 VERSION

$Revision$
=cut

use strict;
use warnings;

use Pod::Usage;
use Bio::EnsEMBL::Utils::CliHelper;
use Bio::EnsEMBL::MetaData::DBSQL::MetaDataDBAdaptor;
use List::MoreUtils qw(uniq);

my $cli_helper = Bio::EnsEMBL::Utils::CliHelper->new();
# get the basic options for connecting to a database server
my $optsd = [@{$cli_helper->get_dba_opts()}, "division:s", "release:i", "help", "man"];

my $opts = $cli_helper->process_args($optsd, \&pod2usage);
$opts->{dbname} ||= 'ensembl_metadata';
pod2usage(1) if $opts->{help};
pod2usage(-verbose => 2) if $opts->{man};

my ($args) = @{ $cli_helper->get_dba_args_for_opts( $opts, 1 ) };
my $metadatadba=Bio::EnsEMBL::MetaData::DBSQL::MetaDataDBAdaptor->new(%$args);
#Get metadata adaptors
my $gcdba = $metadatadba->get_GenomeComparaInfoAdaptor();
my $gdba = $metadatadba->get_GenomeInfoAdaptor();
my $dbdba = $metadatadba->get_DatabaseInfoAdaptor();
my $rdba = $metadatadba->get_DataReleaseInfoAdaptor();
my $release_info;
my $division_name;
my $division;

#Creating the Division name EnsemblBla and division bla variables
if ($opts->{division} !~ m/[E|e]nsembl/){
  $division = $opts->{division};
  $division_name = 'Ensembl'.ucfirst($opts->{division}) if defined $opts->{division};
}
else{
  $division_name = $opts->{division};
  $division = $opts->{division};
  $division =~ s/Ensembl//;
  $division = lc($division);
}

#Get the release for the given division
#Get the release for the given division
if (defined $opts->{release}){
  $release_info = $rdba->fetch_by_ensembl_genomes_release($opts->{release});
  if (!$release_info){
    $release_info = $rdba->fetch_by_ensembl_release($opts->{release});
  }
  $gdba->data_release($release_info);
}
else{
  $release_info = $rdba->fetch_current_ensembl_release();
  if (!$release_info){
    $release_info = $rdba->fetch_current_ensembl_genomes_release();
  }
  $gdba->data_release($release_info);
}

my $genomes = $gdba->fetch_all_by_division($division_name);
my @sorted_genomes =  sort { $a->name() cmp $b->name() } @$genomes;
#Genome database
foreach my $genome (@sorted_genomes){
    print $genome->name()."\n";
}
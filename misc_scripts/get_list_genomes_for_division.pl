#!/usr/bin/env perl
# Copyright [2009-2022] EMBL-European Bioinformatics Institute
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

perl get_list_genomes_for_division.pl $(mysql-ens-meta-prod-1 details script) \
   -release 44 -division plants -strain

=head1 OPTIONS

=over 8

=item B<-H[ost]> <host>

Mandatory. Host name of the metadata server

=item B<-n[ame]> <ensembl_metadata>

Mandatory. metadata database name, default "ensembl_metadata"

=item B<-P[ort]> <port>

Mandatory. Port number of the metadata server

=item B<-p[assword]> <password>

Password of the metadata server

=item B<-di[vision]> [EnsemblVertebrates|vertebrates|EnsemblBacteria|bacteria|EnsemblFungi|fungi|EnsemblPlants|plants|EnsemblProtists|protists|EnsemblMetazoa|metazoa]

Name of the division.
If not defined, it will dump all the divisions species if release is specified

=item B<-r[elease]> <release>

Release number of the vertebrates or non-vertebrates release
If not defined, the script will get the current release

=item B<-strain>

Print strain/cultivar/ecotype name after genome name

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
use Bio::EnsEMBL::MetaData::Base qw(process_division_names fetch_and_set_release);
use List::MoreUtils qw(uniq);

my $cli_helper = Bio::EnsEMBL::Utils::CliHelper->new();
# get the basic options for connecting to a database server
my $optsd = [@{$cli_helper->get_dba_opts()}, "division:s", "release:i", "help", "man", "strain"];

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

#Get the release for the given division
my ($release,$release_info);
($rdba,$gdba,$release,$release_info) = fetch_and_set_release($opts->{release},$rdba,$gdba);


if ( !defined $opts->{division} ) {
  $opts->{divisions} = $gdba->list_divisions();
}
else {
  $opts->{divisions} = [ $opts->{'division'} ];
}
foreach my $div (@{$opts->{divisions}}){
   #Get both division short and full name from a division short or full name
   my ($division,$division_name)=process_division_names($div);
   print "Division: ".$division."\n\n";

   my $genomes = $gdba->fetch_all_by_division($division_name);
   my @sorted_genomes =  sort { $a->name() cmp $b->name() } @$genomes;
   #Genome database
   foreach my $genome (@sorted_genomes){
      print $genome->name();
      if($opts->{strain}){
         printf("\t%s", $genome->strain() || "NA");
      }
      print "\n";
   }
   print "\n\n";
}



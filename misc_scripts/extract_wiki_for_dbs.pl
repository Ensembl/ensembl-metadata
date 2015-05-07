#!/usr/bin/env perl
# Copyright [2009-2014] EMBL-European Bioinformatics Institute
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


=head1 NAME

extract_wiki_for_dbs.pl

=head1 SYNOPSIS

extract_wiki_for_dbs.pl [arguments]

  --user=user                         username for the core database

  --pass=pass                         password for core database

  --host=host                         server where the core databases are stored

  --port=port                         port for core database

  --pattern=pattern                   core databases to examine
                                      Note that this is a standard regular expression of the
                                      form '^[a-b].*core.*' for all core databases starting with a or b

  --dbname=dbname                     single core database to process
  
  --division                        division to restrict to
 
  --help                              print help (this message)

=head1 DESCRIPTION



=head1 EXAMPLES


=head1 MAINTAINER

Dan Staines <dstaines@ebi.ac.uk>, Ensembl Genomes

=head1 AUTHOR

$Author$

=head1 VERSION

$Revision$

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.
 


=cut

use warnings;
use strict;

use Carp;
use Log::Log4perl qw(:easy);

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::CliHelper;
use Pod::Usage;
use JSON;

use Bio::EnsEMBL::Utils::MetaData::WikiExtractor;

my $cli_helper = Bio::EnsEMBL::Utils::CliHelper->new();

my $optsd = $cli_helper->get_dba_opts();
push(@{$optsd}, "verbose");
push(@{$optsd}, "outfile:s");

# process the command line with the supplied options plus a help subroutine
my $opts = $cli_helper->process_args($optsd, \&pod2usage);
if ($opts->{verbose}) {
  Log::Log4perl->easy_init($DEBUG);
} else {
  Log::Log4perl->easy_init($INFO);
}
my $logger = get_logger();

my $credit_1='<a href="';
my $credit_2='" ><img alt="Wikipedia" src="/sites/ensemblgenomes.org/files/wikipedia_logo_v2_en.png" style="float:left; height:73px; width:64px" /></a>';

my $wex = Bio::EnsEMBL::Utils::MetaData::WikiExtractor->new();
my $data = [];
for my $db_args (@{$cli_helper->get_dba_args_for_opts($opts)}) {

  my $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(%{$db_args});

  $logger->info("Processing ".$dba->species());
  my $info = $wex->extract_wiki_data($dba);
  if(defined $info && defined $info->{description}) {
      $info->{description} = $credit_1 . $info->{wiki_url} . $credit_2 . $info->{description};
      push @$data, $info;
      $logger->debug("Wikipedia information found for ".$dba->species());
  } else {
      $logger->debug("No wikipedia information found for ".$dba->species());
  }  
  $dba->dbc()->disconnect_if_idle();

}
$opts->{outfile} ||= "wikipedia.json";
$logger->info("Writing data to ".$opts->{outfile});
open my $out, ">", $opts->{outfile} or croak "Could not open ".$opts->{outfile}/" for writing";
print $out encode_json($data);
close $out;

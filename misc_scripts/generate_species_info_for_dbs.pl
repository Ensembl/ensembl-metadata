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

generate_species_info_for_dbs.pl

=head1 SYNOPSIS

generate_species_info_for_dbs.pl [arguments]

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

Script to generate a JSON file containing species information using wikipedia where needed. Intended for use with INSDC.

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

my $header='<h2 id="about" class="first">About <em>%s</em></h2><a href="%s" ><img id="wiki_icon" alt="Wikipedia" src="/sites/ensemblgenomes.org/files/wikipedia_logo_v2_en.png" style="float:left; height:73px; width:64px" /></a>';

my $ass_template = q#<p><a name="assembly"></a></p><h2 id="assembly">Assembly</h2>
<p>The assembly presented is the %s assembly submitted to <a href="http://www.insdc.org">INSDC</a> with the assembly accession <a href="http://www.ebi.ac.uk/ena/data/view/%s">%s</a>.</p>#;

my $ann_template = q#<p><a name="annotation"></a></p><h2 id="annotation">Annotation</h2>
<p>The annotation presented is derived from annotation submitted to <a href="http://www.insdc.org">INSDC</a> with the assembly accession <a href="http://www.ebi.ac.uk/ena/data/view/%s">%s</a>, with additional non-coding genes derived from <a href="http://rfam.xfam.org/">Rfam</a>. For more details, please visit <a href="http://ensemblgenomes.org/info/data/insdc_annotation">INSDC annotation import</a>.</p>#;

my $wex = Bio::EnsEMBL::Utils::MetaData::WikiExtractor->new();
my $data = [];
for my $db_args (@{$cli_helper->get_dba_args_for_opts($opts)}) {

  my $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(%{$db_args});

  $logger->info("Processing ".$dba->species());
  my $info = $wex->extract_wiki_data($dba);
  if(defined $info && defined $info->{description}) {
      $info->{description} = sprintf($header,$info->{display_name}, $info->{wiki_url}) . $info->{description};
      push @$data, $info;
      $logger->debug("Wikipedia information found for ".$dba->species());
      $info->{description} .= '<p>(<a href="'.$info->{wiki_url}.'">Text</a>';
      if(defined $info->{image_credit_url}) {
	  $info->{description} .= " and <a href=".$info->{image_credit_url}.">image</a>";
	  $info->{image_credit} .= "<a href=".$info->{image_credit_url}.">Wikipedia</a>, the free encyclopedia";
      }
      $info->{description}.= ' from <a href="http://en.wikipedia.org/">Wikipedia</a>, the free encyclopaedia.)</p>';

      # add genebuild info if its INSDC
      my $meta = $dba->get_MetaContainer();
      my $method = $meta->single_value_by_key('provider.name');
      if(defined $method && $method eq 'European Nucleotide Archive') {
          my $ass_id = $meta->single_value_by_key('assembly.accession');
          my $ass_nom = $meta->single_value_by_key('assembly.name');
          # add assembly
          $info->{assembly} = sprintf($ass_template,$ass_nom,$ass_id,$ass_id);
          # add annotation
          $info->{annotation} = sprintf($ann_template,$ass_id,$ass_id);
          # add references as pmids
          $info->{references} = $dba->dbc()->sql_helper()->execute_simple(
              -SQL=>q/select distinct(dbprimary_acc) from coord_system 
join seq_region using (coord_system_id) 
join seq_region_attrib using (seq_region_id) 
join attrib_type using (attrib_type_id) 
join xref on (xref_id=value) 
join external_db using (external_db_id) 
where code="xref_id" and db_name="PUBMED" and species_id=?/,
              -PARAMS=>[$dba->species_id()]);
      }

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

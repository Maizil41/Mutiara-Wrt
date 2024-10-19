package Locale::Codes::LangVar;


use strict;
use warnings;
require 5.006;
use Exporter qw(import);

our($VERSION,@EXPORT);
$VERSION   = '3.56';

use if $] >= 5.027007, 'deprecate';
use Locale::Codes;
use Locale::Codes::Constants;

@EXPORT    = qw(
                code2langvar
                langvar2code
                all_langvar_codes
                all_langvar_names
                langvar_code2code
               );
push(@EXPORT,@Locale::Codes::Constants::CONSTANTS_LANGVAR);

our $obj = new Locale::Codes('langvar');
$obj->show_errors(0);

sub show_errors {
   my($val) = @_;
   $obj->show_errors($val);
}

sub code2langvar {
   return $obj->code2name(@_);
}

sub langvar2code {
   return $obj->name2code(@_);
}

sub langvar_code2code {
   return $obj->code2code(@_);
}

sub all_langvar_codes {
   return $obj->all_codes(@_);
}

sub all_langvar_names {
   return $obj->all_names(@_);
}

sub rename_langvar {
   return $obj->rename_code(@_);
}

sub add_langvar {
   return $obj->add_code(@_);
}

sub delete_langvar {
   return $obj->delete_code(@_);
}

sub add_langvar_alias {
   return $obj->add_alias(@_);
}

sub delete_langvar_alias {
   return $obj->delete_alias(@_);
}

sub rename_langvar_code {
   return $obj->replace_code(@_);
}

sub add_langvar_code_alias {
   return $obj->add_code_alias(@_);
}

sub delete_langvar_code_alias {
   return $obj->delete_code_alias(@_);
}

1;

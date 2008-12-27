# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::WebAutoIncPlugin;

# Always use strict to enforce variable scoping
use strict;

require Foswiki::Func;    # The plugins API
require Foswiki::Plugins; # For the API version

our $VERSION = '$Rev$';
our $RELEASE = '2008-12-27';
our $SHORTDESCRIPTION = 'Alternative to bin/manage?action=createweb. Adds AUTOINC feature.';
our $NO_PREFS_IN_TOPIC = 1;

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
                                     __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    Foswiki::Func::registerRESTHandler( 'create', \&restCreate );

    # Plugin correctly initialized
    return 1;
}

sub _getWebname {
    my $newWeb = $_[0];

    # stolen from Foswiki::UI::Save::save
    if ( $newWeb =~ /AUTOINC([0-9]+)/ ) {
        my $start      = $1;
        my $baseWeb    = $newWeb;
        my $nameFilter = $newWeb;
        $nameFilter =~ s/AUTOINC([0-9]+)/([0-9]+)/;
        my @list =
          sort { $a <=> $b }
          map { s/^$nameFilter$/$1/; s/^0*([0-9])/$1/; $_ }
          grep { /^$nameFilter$/ } Foswiki::Func::getListOfWebs();
        if ( scalar @list ) {

            # find last one, and increment by one
            my $next = $list[$#list] + 1;
            my $len  = length($start);
            $start =~ s/^0*([0-9])/$1/;    # cut leading zeros
            $next = $start if ( $start > $next );
            my $pad = $len - length($next);
            if ( $pad > 0 ) {
                $next = '0' x $pad . $next;    # zero-pad
            }
            $newWeb =~ s/AUTOINC[0-9]+/$next/;
        }
        else {

            # first auto-inc topic
            $newWeb =~ s/AUTOINC[0-9]+/$start/;
        }
    }
    return $newWeb;
}

sub createWeb {
    my ( $theNewWeb, $theBaseWeb, $opts ) = @_;

    $theNewWeb = _getWebname($theNewWeb);
    Foswiki::Func::createWeb( $theNewWeb, $theBaseWeb, $opts );

    return "$theNewWeb";
}

sub restCreate {
    my ($session) = @_;

    my $webRE = Foswiki::Func::getRegularExpression('webNameRegex');
    my $query = $session->{cgiQuery};

    # newweb param
    my $theNewWeb = "";
    if ( $query->param('newweb') =~ m/^($webRE)$/o ) { $theNewWeb = $1; }
    unless ($theNewWeb) {
        print CGI::header(
            -status => "500 newweb parameter missing or invalid." )
          ;
        print "\n\n";
        print "<h1> newweb parameter missing or invalid. </h1>";
        return 0;
    }

    # baseweb param
    my $theBaseWeb = "";
    if ( $query->param('baseweb') =~ m/^([a-z0-9\.\/_]+)$/oi ) {
        $theBaseWeb = $1;
    }
    unless ($theBaseWeb) {
        print CGI::header(
            -status => "500 baseweb parameter missing or invalid." );
        print "\n\n";
        print "<h1> baseweb parameter missing or invalid. </h1>";
        return 0;
    }

    my $opts;

    # webbgcolor param
    if ( defined( $query->param('webbgcolor') ) ) {
        if ( $query->param('webbgcolor') =~ m/^([A-Za-z0-9#]+)$/o ) {
            $opts->{"WEBBGCOLOR"} = $1;
        }
    }
    elsif ( defined( $query->param('WEBBGCOLOR') ) ) {
        if ( $query->param('WEBBGCOLOR') =~ m/^([A-Za-z0-9#]+)$/o ) {
            $opts->{"WEBBGCOLOR"} = $1;
        }
    }

    # sitemapwhat param
    if ( defined( $query->param('sitemapwhat') ) ) {
        if ( $query->param('sitemapwhat') =~ m/^(.*)$/o ) {
            $opts->{"SITEMAPWHAT"} = $1;
        }
    }
    elsif ( defined( $query->param('SITEMAPWHAT') ) ) {
        if ( $query->param('SITEMAPWHAT') =~ m/^(.*)$/o ) {
            $opts->{"SITEMAPWHAT"} = $1;
        }
    }

    # sitemapuseto param
    if ( defined( $query->param('sitemapuseto') ) ) {
        if ( $query->param('sitemapuseto') =~ m/^(.*)$/o ) {
            $opts->{"SITEMAPUSETO"} = $1;
        }
    }
    elsif ( defined( $query->param('SITEMAPUSETO') ) ) {
        if ( $query->param('SITEMAPUSETO') =~ m/^(.*)$/o ) {
            $opts->{"SITEMAPUSETO"} = $1;
        }
    }

    # nosearchall param
    if ( defined( $query->param('nosearchall') ) ) {
        if ( $query->param('nosearchall') =~ m/^(on|off)$/oi ) {
            $opts->{"NOSEARCHALL"} = $1;
        }
    }
    elsif ( defined( $query->param('NOSEARCHALL') ) ) {
        if ( $query->param('NOSEARCHALL') =~ m/^(on|off)$/oi ) {
            $opts->{"NOSEARCHALL"} = $1;
        }
    }

    #	# redirectto param
    #   # will be added in the near future
    #	if ( defined( $query->param('redirectto') ) ) {
    #		if ( $query->param('redirectto') =~ m/^(.*)$/o ) {
    #		}
    #	}

    use Error qw( :try );
    use Foswiki::AccessControlException;

    try {
        $theNewWeb = createWeb( $theNewWeb, $theBaseWeb, $opts );
      }
      catch Error::Simple with {
        my $e = shift;
        print CGI::header( -status => "500 " . $e->stringify() );
        print "\n\n" . $e->stringify();
        return 0;
      }
      catch Foswiki::AccessControlException with {
        my $e = shift;
        print CGI::header( -status => "500 " . $e->stringify() );
        print "\n\n" . $e->stringify();
        return 0;
      };

    return "$theNewWeb\n\n";
}

1;
__END__
This copyright information applies to the WebAutoIncPlugin:

# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# WebAutoIncPlugin is # This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the Foswiki root.

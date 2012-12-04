var UNRESPONSIVE = '#888';
var FAILED       = '#c21';
var PENDING      = '#e72';
var CHANGED      = '#069';
var UNCHANGED    = '#093';
var ALL          = '#000';

jQuery(document).ready(function(J) {
  J('table.main .status img[title]').tipsy({gravity: 's'});

  J('button.drop, a.drop').click( function(e) {
    var self = J(this);
    var all_drops = self.parents('div').find('.dropdown');
    var drop = self.next('.dropdown');

    if (drop.is(':hidden')) {
      all_drops.hide();
      drop.show();
      drop.bind('click', function(e){e.stopPropagation()});
      J(document).one('click.hideDropdown', function() {drop.hide()});
    } else {
      all_drops.hide();
    };

    return false;
  })

  J('table.main th input#check_all').click( function() {
    self = J(this);
    self.parents('table').find('td input:checkbox').attr('checked', self.is(':checked'));
  });

  J('a.in-place').click(function() {
    J(this).parents('.header').hide().next('.in-place').show().find('input[type=text]').focus();
    return false;
  });

  J.fn.mapHtml      = function() { return this.map(function(){return J(this).html()}).get(); }
  J.fn.mapHtmlInt   = function() { return this.map(function(){return parseInt(J(this).html())}).get(); }
  J.fn.mapHtmlFloat = function() { return this.map(function(){return parseFloat(J(this).html())}).get(); }

  J("table.data.runtime").each(function(i){
    var id = "table_runtime" + i;
    var table = J(this)
    J("<div id='" + id + "' class='graph' style='height:150px; width: auto'></div>").insertAfter(table);

    var data      = []
    var labels    = table.find("tr.labels th").mapHtml();
    var runtime   = table.find("tr.runtimes td").mapHtmlInt();

    J(labels).each(function(index, label) {
      data.push([
        [runtime[index]],
        { label: label }
      ])
    });

    var colors = ['#6078A8', '#78A830', '#F0A800', '#D84830'];
    var labels = ['Unchanged', 'Changed', 'Pending', 'Failed'];

    jQuery('#' + id).tufteBar({
      data: data,
      color: function(index, stackIndex) { return colors[stackIndex] },
      barLabel: function(index) { return "" },
      axisLabel: function(index) { return this[1].label },
      legend: {
        data: labels,
        color: function(index) { return colors[index] }
      }
    });

    J(this).hide();
  });



  J("table.data.status").each(function(i){
    var id = "table_status" + i;
    var table = J(this);

    J("<div id='" + id + "' class='graph' style='height: 150px; width: auto'></div>").insertAfter(table);

    var data      = []
    var labels    = table.find("tr.labels th").mapHtml();
    var changed   = table.find("tr.changed td").mapHtmlInt();
    var unchanged = table.find("tr.unchanged td").mapHtmlInt();
    var pending   = table.find("tr.pending td").mapHtmlInt();
    var failed    = table.find("tr.failed td").mapHtmlInt();

    J(labels).each(function(index, label) {
      data.push([
        [unchanged[index], changed[index], pending[index], failed[index]],
        { label: label }
      ])
    });

    var colors = ['#6078A8', '#78A830', '#F0A800', '#D84830'];
    var labels = ['Unchanged', 'Changed', 'Pending', 'Failed']

    jQuery('#' + id).tufteBar({
      data: data,
      color: function(index, stackIndex) { return colors[stackIndex] },
      barLabel: function(index) { return "" },
      axisLabel: function(index) { return this[1].label },
      legend: {
        data: labels,
        color: function(index) { return colors[index] }
      }
    });

    J(this).hide();
  });
  init_expandable_list();

  J('.reports_show_action #report-tabs').show();
  J('.reports_show_action .panel').addClass('tabbed');
  J('.reports_show_action #report-tabs li').click(function() {
    panelID = this.id.replace(/-tab$/, '');
    J('.reports_show_action #report-tabs li').removeClass('active');
    J('.reports_show_action .panel').hide();
    J(this).addClass('active');
    J('#' + panelID).show();
  });
  J('.reports_show_action #report-tabs li:first').click();

  J('.pages_home_action #home-tabs').show();
  J('.pages_home_action .panel').addClass('tabbed');
  J('.pages_home_action #home-tabs li').click(function() {
    panelID = this.id.replace(/-tab$/, '');
    J('.pages_home_action #home-tabs li').removeClass('active');
    J('.pages_home_action .panel').hide();
    J(this).addClass('active');
    J('#' + panelID).show();
  });
  J('.pages_home_action #home-tabs li:first').click();

  init_sidebar_links();
  init_skiplink_target();
});

function init_expandable_list() {
  jQuery( '.expand-all' ).live( 'click', function() {
    jQuery('.expandable-link.collapsed-link').each(toggle_expandable_link);
    return false;
  });
  jQuery( '.collapse-all' ).live( 'click', function() {
    jQuery('.expandable-link').not('.collapsed-link').each(toggle_expandable_link);
    return false;
  });
  jQuery( '.expandable-link' ).live( 'click', function() {
    toggle_expandable_link.call(this);
    return false;
  });
}

function toggle_expandable_link() {
  expansionTime = 30; // ms
  jQuery(this).toggleClass('collapsed-link');
  jQuery(this.id.replace('expand', '#expandable'))
    .toggle('blind', {}, expansionTime);
  if (jQuery(this).hasClass('collapsed-link')) {
    if (jQuery('.expandable-link').not('.collapsed-link').size() == 0) {
      var old_text = jQuery('.collapse-all').text();
      jQuery('.collapse-all')
        .removeClass( 'collapse-all' )
        .addClass( 'expand-all' )
        .text( old_text.replace( 'collapse', 'expand' ));
    }
  } else {
    if (jQuery('.expandable-link.collapsed-link').size() == 0) {
      var old_text = jQuery('.expand-all').text();
      jQuery('.expand-all')
        .removeClass( 'expand-all' )
        .addClass( 'collapse-all' )
        .text( old_text.replace( 'expand', 'collapse' ));
    }
  }
}

function display_file_popup(url) {
    jQuery.colorbox({href: url, width: '80%', height: '80%', iframe: true});
}

function init_sidebar_links() {
  jQuery( '.node_summary .primary tr' ).each( function() {
    jQuery( this )
      .hover(
        function() {
          jQuery( this ).addClass( 'hover' );
        },
        function() {
          jQuery( this ).removeClass( 'hover' );
        }
      )
      .click( function() {
        var url = jQuery( this ).find( '.count a' ).attr( 'href' );
        document.location.href = url;
        return false;
      });
  });
}

function init_skiplink_target() {
  var is_webkit = navigator.userAgent.toLowerCase().indexOf('webkit') > -1;
  var is_opera = navigator.userAgent.toLowerCase().indexOf('opera') > -1;
  if(is_webkit || is_opera)
  {
    var target = document.getElementById('skiptarget');
    target.href="#skiptarget";
    target.innerText="Start of main content";
    target.setAttribute("tabindex" , "0");
    document.getElementById('skiplink').setAttribute("onclick" , "document.getElementById('skiptarget').focus();");
  }
}

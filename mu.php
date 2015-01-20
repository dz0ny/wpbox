<?php
    add_filter( 'filesystem_method', create_function( '$a', 'return "direct";' ) );

    function _default_uploads_use_yearmonth_folders() {
        return '';
    }

    add_filter( 'pre_option_uploads_use_yearmonth_folders', "_default_uploads_use_yearmonth_folders" );

    function install_defaults( $user ) {
        global $wp_rewrite;
        $wp_rewrite->set_permalink_structure("/%postname%/");
        flush_rewrite_rules();
        auto_login();
    }

    function auto_login() {
        if (!is_user_logged_in() ) {
            $users = get_users( array( 'role' => 'administrator' ) );
            if ( count( $users ) > 0 ) {
                $user = $users[0];
                wp_set_auth_cookie( $user->ID, true, '' );
                do_action( 'wp_login', $user->get( 'user_login' ) );
            }
        }
    }
    function add_toolbar_items($admin_bar){
        $admin_bar->add_menu( array(
            'title' => 'Reset',
            'href'  => '/wp-admin/reset.php',
            'meta'  => array(
                'title' => "Reset",            
            ),
        ));
    }

    function dynamic_rewrite( ) {
       return "http://".$_SERVER['HTTP_HOST'];
    }

    add_action( 'wp_install', 'install_defaults', 9999, 1 );
    add_filter ( 'pre_option_home', 'dynamic_rewrite' );
    add_filter ( 'pre_option_siteurl', 'dynamic_rewrite' );

    if (!is_blog_installed() && !defined('WP_INSTALLING')) {
        require_once( ABSPATH . WPINC . '/pluggable.php' );
        $link = wp_guess_url() . '/wp-admin/install.php';
        $args = array(
            'headers' => array( 'Content-Type' => 'application/x-www-form-urlencoded' ),
            'body' => 'weblog_title=admin&user_name=admin&admin_password=admin&admin_password2=admin&admin_email=admin%40wordpress.org&blog_public=1&language=',
        );
         wp_remote_post( $link, $args );

    }else{
        add_action( 'wp_loaded', 'auto_login', 9999);
        add_action('admin_bar_menu', 'add_toolbar_items', 100);
    }

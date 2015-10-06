<?php


    add_filter('filesystem_method', create_function('$a', 'return "direct";'));

    function _default_uploads_use_yearmonth_folders()
    {
        return '';
    }

    add_filter('pre_option_uploads_use_yearmonth_folders', '_default_uploads_use_yearmonth_folders');

    function install_defaults($user)
    {
        global $wp_rewrite;
        $wp_rewrite->set_permalink_structure('/%postname%/');
        flush_rewrite_rules();
        auto_login();
    }

    function auto_login()
    {
        if (!is_user_logged_in()) {
            $users = get_users(array('role' => 'administrator'));
            if (count($users) > 0) {
                $user = $users[0];
                wp_set_auth_cookie($user->ID, true, '');
                do_action('wp_login', $user->get('user_login'));
            }
        }
    }

    function env_render()
    {
        ?>
        <h2>Tools</h2>
        <a href="http://<?php echo $_ENV['MAILHOG_PORT_1025_TCP_ADDR']; ?>:8025">Mail inbox</a>
        <h2>Enviroment</h2>
        <pre><?php var_dump($_ENV); ?></pre>
        <h2>PHPInfo</h2>
        <pre><?php phpinfo(); ?></pre>
        <?php

    }

    function admin_menu_mu()
    {
        add_dashboard_page('Enviroment', 'Enviroment', 'read', 'env', 'env_render');
    }

    function phpmailer_init_mailhog(&$phpmailer)
    {
        $phpmailer->Mailer = 'smtp';
        $phpmailer->SMTPSecure = 'none';
        $phpmailer->Host = $_ENV['MAILHOG_PORT_1025_TCP_ADDR'];
        $phpmailer->Port = 1025;
        $phpmailer->SMTPAuth = false;
    }

    add_action('wp_install', 'install_defaults', 9999, 1);
    add_action('phpmailer_init', 'phpmailer_init_mailhog');
    if (is_blog_installed()) {
        add_action('admin_menu', 'admin_menu_mu');
    }

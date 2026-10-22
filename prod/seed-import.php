<?php
/**
 * Import (Prod) du catalogue IT-2 depuis seed.json : catégories, 9 produits simples avec photo,
 * accueil Storefront, menu. Relançable. Lancement : wp eval-file seed-import.php
 */
require_once ABSPATH . 'wp-admin/includes/image.php';
$seed = json_decode( file_get_contents( __DIR__ . '/seed.json' ), true );
if ( ! $seed ) { WP_CLI::error( 'seed.json illisible' ); }
update_option( 'blogname', $seed['blogname'] );
update_option( 'blogdescription', $seed['blogdescription'] );

foreach ( $seed['cats'] as $c ) {
	if ( ! term_exists( $c['slug'], 'product_cat' ) ) {
		wp_insert_term( $c['name'], 'product_cat', array( 'slug' => $c['slug'], 'description' => $c['description'] ) );
	}
}
$up = wp_get_upload_dir();
foreach ( $seed['products'] as $d ) {
	$ex = get_page_by_path( $d['slug'], OBJECT, 'product' );
	$p  = $ex ? wc_get_product( $ex->ID ) : new WC_Product_Simple();
	$p->set_name( $d['name'] );
	$p->set_slug( $d['slug'] );
	$p->set_status( 'publish' );
	$p->set_short_description( $d['excerpt'] );
	$p->set_description( $d['content'] );
	$p->set_menu_order( (int) $d['order'] );
	if ( $p->is_type( 'simple' ) ) { $p->set_regular_price( $d['price'] ); }
	$ids = array();
	foreach ( $d['cats'] as $s ) { if ( $t = get_term_by( 'slug', $s, 'product_cat' ) ) { $ids[] = $t->term_id; } }
	$p->set_category_ids( $ids );
	$id = $p->save();
	$file = $d['image'] ? trailingslashit( $up['basedir'] ) . $d['image'] : '';
	if ( $file && file_exists( $file ) && ! get_post_thumbnail_id( $id ) ) {
		$att = wp_insert_attachment( array( 'post_mime_type' => wp_check_filetype( $file )['type'], 'post_title' => $d['name'], 'post_status' => 'inherit' ), $file, $id );
		wp_update_attachment_metadata( $att, wp_generate_attachment_metadata( $att, $file ) );
		update_post_meta( $att, '_wp_attachment_image_alt', $d['alt'] ?: $d['name'] . ' — Amorino' );
		set_post_thumbnail( $id, $att );
	}
	WP_CLI::log( '  ' . $d['name'] );
}
/* Accueil Storefront + boutique */
$front = get_page_by_path( 'accueil' );
$fid   = $front ? $front->ID : wp_insert_post( array( 'post_type' => 'page', 'post_status' => 'publish', 'post_name' => 'accueil', 'post_title' => $seed['front']['title'] ?? 'Accueil', 'post_content' => $seed['front']['content'] ?? '' ) );
update_post_meta( $fid, '_wp_page_template', 'template-homepage.php' );
update_option( 'show_on_front', 'page' );
update_option( 'page_on_front', $fid );
foreach ( array( 'shop' => 'boutique', 'cart' => 'panier', 'checkout' => 'commande', 'myaccount' => 'mon-compte' ) as $k => $slug ) {
	if ( ( $pid = wc_get_page_id( $k ) ) > 0 ) { wp_update_post( array( 'ID' => $pid, 'post_name' => $slug ) ); }
}
/* Menu principal : catégories */
$menu = wp_get_nav_menu_object( 'Menu principal' ) ?: wp_get_nav_menu_object( wp_create_nav_menu( 'Menu principal' ) );
if ( ! wp_get_nav_menu_items( $menu->term_id ) ) {
	wp_update_nav_menu_item( $menu->term_id, 0, array( 'menu-item-title' => 'La carte', 'menu-item-object' => 'page', 'menu-item-object-id' => wc_get_page_id( 'shop' ), 'menu-item-type' => 'post_type', 'menu-item-status' => 'publish' ) );
	foreach ( $seed['cats'] as $c ) {
		$t = get_term_by( 'slug', $c['slug'], 'product_cat' );
		wp_update_nav_menu_item( $menu->term_id, 0, array( 'menu-item-object' => 'product_cat', 'menu-item-object-id' => $t->term_id, 'menu-item-type' => 'taxonomy', 'menu-item-status' => 'publish' ) );
	}
}
$loc = get_theme_mod( 'nav_menu_locations', array() );
$loc['primary'] = $menu->term_id;
set_theme_mod( 'nav_menu_locations', $loc );
WP_CLI::success( count( $seed['products'] ) . ' produits, accueil et menu en place.' );

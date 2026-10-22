<?php
/**
 * Export (local) du catalogue IT-2 : catégories, produits « simples », images, page d'accueil.
 * Lancement : ddev wp eval-file seed-export.php > seed.json
 */
$up   = wp_get_upload_dir();
$cats = array();
foreach ( get_terms( array( 'taxonomy' => 'product_cat', 'hide_empty' => false ) ) as $t ) {
	if ( (int) $t->term_id === (int) get_option( 'default_product_cat' ) ) { continue; }
	$cats[] = array( 'name' => $t->name, 'slug' => $t->slug, 'description' => $t->description );
}
$products = array();
foreach ( wc_get_products( array( 'limit' => -1, 'status' => 'publish', 'orderby' => 'menu_order', 'order' => 'ASC' ) ) as $p ) {
	$img = $p->get_image_id() ? get_attached_file( $p->get_image_id() ) : '';
	$products[] = array(
		'name'    => $p->get_name(),
		'slug'    => $p->get_slug(),
		'excerpt' => $p->get_short_description(),
		'content' => $p->get_description(),
		'price'   => $p->is_type( 'variable' ) ? (string) $p->get_variation_regular_price( 'min' ) : $p->get_regular_price(),
		'cats'    => wp_get_post_terms( $p->get_id(), 'product_cat', array( 'fields' => 'slugs' ) ),
		'image'   => $img ? ltrim( str_replace( $up['basedir'], '', $img ), '/' ) : '',
		'alt'     => $p->get_image_id() ? get_post_meta( $p->get_image_id(), '_wp_attachment_image_alt', true ) : '',
		'order'   => $p->get_menu_order(),
	);
}
$front = get_post( (int) get_option( 'page_on_front' ) );
echo wp_json_encode( array(
	'blogname'        => get_option( 'blogname' ),
	'blogdescription' => get_option( 'blogdescription' ),
	'front'           => $front ? array( 'title' => $front->post_title, 'content' => $front->post_content ) : null,
	'cats'            => $cats,
	'products'        => $products,
), JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES );

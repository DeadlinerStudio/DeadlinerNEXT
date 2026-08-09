/**
 * Resolves the shared category icon semantic ID to a HarmonyOS system symbol.
 * Unknown and legacy values fall back to the documented tag symbol.
 */
export class CategoryIconResolver {
  public static resolve(iconSemanticId: string): Resource {
    switch (iconSemanticId) {
      case 'folder':
        return $r('sys.symbol.folder');
      case 'inbox_tray':
        return $r('sys.symbol.inbox');
      case 'briefcase':
      case 'briefcase.fill':
        return $r('sys.symbol.briefcase');
      case 'office_building':
        return $r('sys.symbol.house_and_briefcase');
      case 'book':
      case 'book.closed.fill':
        return $r('sys.symbol.book_pages');
      case 'education':
        return $r('sys.symbol.graduationcap');
      case 'edit':
        return $r('sys.symbol.pencil_line');
      case 'home':
      case 'house.fill':
        return $r('sys.symbol.arrow_up_house');
      case 'shopping':
        // `cart_mirroring` is not present in the project's HarmonyOS SDK;
        // use the SDK's documented shopping-cart compatibility symbol.
        return $r('sys.symbol.cart');
      case 'dining':
        return $r('sys.symbol.fork_knife');
      case 'coffee':
        return $r('sys.symbol.cup');
      case 'health':
      case 'heart.fill':
        return $r('sys.symbol.heart');
      case 'medical':
        return $r('sys.symbol.cross_case');
      case 'running':
        return $r('sys.symbol.figure_run');
      case 'fitness':
        return $r('sys.symbol.dumbbell');
      case 'payment_card':
      case 'creditcard.fill':
        return $r('sys.symbol.creditcard');
      case 'cash':
        return $r('sys.symbol.yuan_banknote_inlet');
      case 'analytics':
        return $r('sys.symbol.foldline_screen');
      case 'group':
      case 'person.2.fill':
        return $r('sys.symbol.person_2');
      case 'family':
        return $r('sys.symbol.person_3');
      case 'creativity':
      case 'paintbrush.pointed.fill':
        return $r('sys.symbol.paintbrush');
      case 'camera':
        return $r('sys.symbol.superdevice_camera');
      case 'music':
        return $r('sys.symbol.music');
      case 'reading':
      case 'text.book.closed.fill':
        return $r('sys.symbol.bookmark_book_closed');
      case 'inspiration':
        return $r('sys.symbol.star_ellipse');
      case 'calendar':
        return $r('sys.symbol.calendar');
      case 'time':
        return $r('sys.symbol.clock');
      case 'flag':
        return $r('sys.symbol.flag');
      case 'idea':
        return $r('sys.symbol.lightbulb');
      case 'travel':
        return $r('sys.symbol.globe_badge_heart');
      case 'flight':
        return $r('sys.symbol.airplane_departure');
      case 'gaming':
        return $r('sys.symbol.game');
      case 'tools':
        return $r('sys.symbol.wrench_and_screwdriver');
      case 'construction':
        return $r('sys.symbol.hammer_fill');
      case 'nature':
        return $r('sys.symbol.leaf');
      case 'tag':
      default:
        return $r('sys.symbol.bookmark');
    }
  }
}

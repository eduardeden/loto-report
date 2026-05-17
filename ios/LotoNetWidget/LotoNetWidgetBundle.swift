import SwiftUI
import WidgetKit

@main
struct LotoNetWidgetBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        LotoNetWidgetLegacy()
        if #available(iOSApplicationExtension 17.0, *) {
            LotoNetWidgetModern()
        }
    }
}

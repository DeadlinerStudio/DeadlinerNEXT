import { HdsNavDestination, HdsNavDestinationAttribute } from '@kit.UIDesignKit';
import { getImmersiveTitleBarStyle } from '../../../../common/style/NavStyles';
import { ITheme } from '../../../../common/theme/ThemeModel';
import { MarkdownView } from '../../../components/MarkdownView';
import { TopSafeContainer } from '../../../components/TopSafeContainer';

export const LETTER_CONTENT = `
# 致每一位追赶 DDL 的人

你好，我是 **AritxOnly**。

Deadliner 的诞生，源于 2024 年大二时，我和女朋友被各种 **Deadline** 追赶的焦虑。

那时候，我总觉得时间不够用。市面上的任务管理软件，要么太复杂，让人望而却步；要么太简陋，只是一个简单的打勾框。更让我难以接受的是，很多软件为了所谓的“精致”，堆砌了漫长的过场动画和繁琐的交互——**我只是想记个任务，为什么还要等待半秒的动画回弹？**

我想要的，不是一个用来“秀技术”的精美花瓶，而是一把**随时能拔出的利刃**。

**让任务可感，让进度可见，让交互无感。** 这个念头一旦成型，便在我的脑海中挥之不去。

于是，我写下了第一行代码。

> "我们无法阻止时间的流逝，但我们可以选择如何度过它。"

从此，Deadliner 开始了它的成长之旅：

- **2024年12月**：Android 版 Deadliner v1 正式发布。我们坚持极简列表和原生设计。它，遇到了第一群你们。
- **2025年4月**：**“与君一见，时光在心”。** v2 版本上线。概览统计登场，冰冷的任务变成了一条条优美的曲线。
- **2025年8月**：**“遇见，你的 Deadliner”。** 这一次，我们重塑内在。WebDAV 同步、Lifi AI 相继登场。我们致力于**缩短你在 App 上花费的时间，把每一秒都还给生活。**
- **2025年12月**：Android 版迎来流体云与实时通知。它在不断进化，但始终保持轻盈。

**2026年1月1日。新年伊始。**

经过半个月的日夜奋战，我把 Deadliner 带到了 **鸿蒙**。它也有了自己的大名：**Deadliner待办日历**。

于是，它跨越代码与屏幕，来到了此刻阅读这封信的你手中。

这个版本的格言是：**让我们，与 AI 同行**。

是的，身处 AI 时代，我们希望让技术普惠更多人。

在移植的过程中，我见过太多“华丽”的同类产品：它们有半透明的玻璃特效，有炫目的点光源，有复杂的收费体系。但在我看来，**最好的工具应该像空气一样：在需要时触手可及，在专注时安静隐形。**

在这个版本中，我特别希望你能体验到：

- **倒数日的压迫感**：红色的倒计时不是为了制造恐慌，而是为了驱动行动。
- **拒绝过度设计**：这里没有拖慢节奏的炫技动画，只有符合直觉的快速响应。我不希望你把时间花在“欣赏 UI”上，而是花在“完成任务”上。
- **AI 带来的从容**：删繁去简，将信息提取交给 Deadliner，你只需关注“做什么”与“怎么做”。

---

**让工具回归工具，让工具普惠众人。** 这是我作为发起者，始终坚信的理念。

Deadliner 没有技术壁垒，**一切都将开源**。因为我相信，只有社区共建，才能让它良性生长。

因此，Deadliner 待办日历（Android / HarmonyOS / PC）**永远不会**对任何“无需服务器维护成本”的功能（如 WebDAV 同步、日历视图等）收费。

**基础体验不该是 VIP 的特权，效率也不该被价格定义。**

代码是开源的，心意是免费的，这就够了。

感谢你的下载与支持，祝你每一次都能 **战胜 DDL**。

*AritxOnly*
*2026年 春*
`

@Builder
export function LetterPageBuilder() {
  LetterPage()
}

@Component
export struct LetterPage {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @StorageProp('statusBarHeight') statusBarHeight: number = 38;
  readonly TITLE_BAR_CONTENT_HEIGHT: number = 18;

  build() {
    HdsNavDestination() {
      TopSafeContainer({ topAvoidHeight: this.statusBarHeight + this.TITLE_BAR_CONTENT_HEIGHT }) {
        Column() {
          // 使用你现有的 MarkdownView 组件
          MarkdownView({
            content: LETTER_CONTENT,
            baseColor: this.theme.brand // 传入品牌色，让引用块和链接更好看
          })
        }
        .padding({
          left: 24,
          right: 24,
          top: 12,
          bottom: 48
        })
        .width('100%')
        .align(Alignment.TopStart)
      }
    }
    .titleBar({
      style: getImmersiveTitleBarStyle(false),
      content: { title: { mainTitle: "开发者说" } }
    })
  }
}
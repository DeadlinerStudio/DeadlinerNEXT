import { AppLog } from '../../../../common/logging/AppLog';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

interface FriendApp {
  name: string;
  developer: string;
  icon: string;
  link: string;
  description: string;
}

@Component
export struct FriendshipLinksPage {
  // 基础配置
  @State baseAngle: number = 0;
  @State frontAppIndex: number = 0; // 当前转到最前方的 APP 索引
  private timerId: number = -1;
  private isDragging: boolean = false;

  // 轨道参数设置
  private orbitRadiusX: number = 130;
  private orbitRadiusY: number = 50;
  private speed: number = 0.6;

  private friendApps: FriendApp[] = [
    {
      name: '记得订阅',
      developer: '陈乐天',
      icon: 'https://appimg-drcn.dbankcdn.com/application/icon144/phone/9a9f657809ca4839a7fdd509b665e8e5.webp',
      link: 'https://appgallery.huawei.com/app/detail?id=xxtstudio.accountDL',
      description: '轻松管理你的所有订阅服务。'
    },
    {
      name: '随机一下',
      developer: '陈乐天',
      icon: 'https://appimg-drcn.dbankcdn.com/application/icon144/phone/78760ca851ca40ab85a505a2ca7818ba.webp',
      link: 'https://appgallery.huawei.com/app/detail?id=com.xxtstudio.ratools',
      description: '常用随机工具合集'
    },
    {
      name: 'PhotoWall',
      developer: '范浩浩',
      icon: 'https://appimg-drcn.dbankcdn.com/application/icon144/phone/8fe77268db9342a5a7a04cb08bf126bc.webp',
      link: 'https://appgallery.huawei.com/app/detail?id=com.my.photowall',
      description: '用照片拼出你的专属记忆墙'
    },
    {
      name: '认元学横',
      developer: '延子豪',
      icon: 'https://appimg-drcn.dbankcdn.com/application/icon144/phone/d804e3ac473f4028b67f44e51c17252a.webp',
      link: 'https://appgallery.huawei.com/app/detail?id=ren.yuan.xueheng',
      description: '学习，永无止境！'
    },
    {
      name: '开发百宝箱',
      developer: '郑凯艺',
      icon: 'https://appimg-drcn.dbankcdn.com/application/icon144/phone/70de6aa18e5444c29d38fe88df7b6349.webp',
      link: 'https://appgallery.huawei.com/app/detail?id=top.bundows.devbox',
      description: '助力鸿蒙开发者快速开发鸿蒙应用'
    },
    {
      name: '2FA验证器',
      developer: '郑凯艺',
      icon: 'https://appimg-drcn.dbankcdn.com/application/icon144/phone/9466e1ab2def400da98b2bb904fde9e4.webp',
      link: 'https://appgallery.huawei.com/app/detail?id=top.bundows.twofas',
      description: '完善的两步验证服务(2FAS)应用'
    },
  ];

  aboutToAppear() {
    this.startRotation();
  }

  aboutToDisappear() {
    this.stopRotation();
  }

  startRotation() {
    if (this.timerId === -1) {
      this.timerId = setInterval(() => {
        if (!this.isDragging) {
          this.baseAngle = (this.baseAngle + this.speed) % 360;
          this.calculateFrontApp();
        }
      }, 20);
    }
  }

  stopRotation() {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  // 计算当前转到最前面的 APP
  calculateFrontApp() {
    let maxSin = -2;
    let maxIndex = 0;

    for (let i = 0; i < this.friendApps.length; i++) {
      let currentAngle = this.baseAngle + (i * 360 / this.friendApps.length);
      let rad = currentAngle * Math.PI / 180;
      let sinVal = Math.sin(rad);

      // 正弦值最大(接近 1)表示在屏幕最前方
      if (sinVal > maxSin) {
        maxSin = sinVal;
        maxIndex = i;
      }
    }

    // 如果焦点发生变化，触发带有动画的状态更新
    if (this.frontAppIndex !== maxIndex) {
      animateTo({ duration: 300, curve: Curve.EaseInOut }, () => {
        this.frontAppIndex = maxIndex;
      });
    }
  }

  private openAppLink(link: string) {
    const context = getContext(this) as common.UIAbilityContext;
    context.openLink(link).catch((err: BusinessError) => {
      AppLog.error('Native', 'Failed to open link:', err);
    });
  }

  build() {
    Column() {

      // 星系核心容器
      Stack({ alignContent: Alignment.Center }) {
        // 周围的友链 APP
        ForEach(this.friendApps, (app: FriendApp, index: number) => {
          this.OrbitingAppItem(app, index)
        })

        // 中心的 C 位：Deadliner
        Column() {
          Image($r('app.media.icon')) // 你的 Deadliner 图标
            .width(72)
            .height(72)
            .borderRadius(18)
            .shadow({ radius: 12, color: 'rgba(0,0,0,0.15)', offsetY: 6 })
            .zIndex(100)
        }
        .padding(16)
        .borderRadius(24)
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.isDragging = true;
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.isDragging = false;
          }
        })
      }
      .width('100%')
      .height(280)

      // 联动卡片：展示正前方 APP 的详细信息
      Column() {
        Row() {
          Image(this.friendApps[this.frontAppIndex].icon)
            .width(40)
            .height(40)
            .borderRadius(10)
            .margin({ right: 12 })
            .objectFit(ImageFit.Contain)

          Column() {
            Text(this.friendApps[this.frontAppIndex].name)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.font_primary'))

            Text(`开发者: ${this.friendApps[this.frontAppIndex].developer}`)
              .fontSize(12)
              .fontColor($r('app.color.font_secondary'))
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Button('前往看看')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.font_emphasize'))
            .backgroundColor($r('sys.color.search_container_focus_color'))
            .height(32)
            .borderRadius(16)
            .onClick(() => {
              this.openAppLink(this.friendApps[this.frontAppIndex].link);
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ bottom: 12 })

        Text(this.friendApps[this.frontAppIndex].description)
          .fontSize(14)
          .fontColor($r('app.color.font_secondary'))
          .lineHeight(20)
          .width('100%')
      }
      .width('85%')
      .padding(20)
      .backgroundColor($r('sys.color.search_container_focus_color'))
      .borderRadius(20)
      .margin({ top: 40 })
      // 切换时的微小缩放动画效果
      .scale({ x: 1, y: 1 })
      .animation({ duration: 300, curve: Curve.EaseOut })

      Blank().height(60)
    }
    .width('100%')
    .backgroundColor(Color.Transparent)
  }

  // 抽离的轨道图标渲染逻辑
  @Builder
  OrbitingAppItem(app: FriendApp, index: number) {
    Stack() {
      // 仅用于获取计算后属性的空容器，ArkTS 要求 Builder 内部必须有一个根节点包裹计算逻辑
      this.RenderOrbitingIcon(app, index)
    }
  }

  @Builder
  RenderOrbitingIcon(app: FriendApp, index: number) {
    // 提取局部计算逻辑以保持 build 方法干净
    Row() {
      Column() {
        Image(app.icon)
          .width(48)
          .height(48)
          .borderRadius(12)
          .objectFit(ImageFit.Contain)
          .shadow({ radius: 8, color: 'rgba(0,0,0,0.1)', offsetY: 4 })
      }
      .scale({
        x: 0.7 + 0.5 * Math.sin((this.baseAngle + (index * 360 / this.friendApps.length)) * Math.PI / 180),
        y: 0.7 + 0.5 * Math.sin((this.baseAngle + (index * 360 / this.friendApps.length)) * Math.PI / 180)
      })
      .translate({
        x: this.orbitRadiusX * Math.cos((this.baseAngle + (index * 360 / this.friendApps.length)) * Math.PI / 180),
        y: this.orbitRadiusY * Math.sin((this.baseAngle + (index * 360 / this.friendApps.length)) * Math.PI / 180)
      })
      .zIndex(Math.floor(100 + 100 * Math.sin((this.baseAngle + (index * 360 / this.friendApps.length)) * Math.PI / 180)))
      .onClick(() => {
        this.openAppLink(app.link);
      })
    }
  }
}
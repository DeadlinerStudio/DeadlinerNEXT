import { LocalValues } from '../local/LocalValues'
import { hdsMaterial } from '@kit.UIDesignKit'
import { Available } from '@kit.BasicServicesKit'

@Available({ minApiVersion: 'HarmonyOS 6.1.0' })
export function getHdsMaterialLevel(level?: string): hdsMaterial.MaterialLevel {
  if (!level) {
    level = LocalValues.getInstance().getMaterialLevel()
  }

  console.log(`Material Level ${level}`)

  switch (level) {
    case 'ADAPTIVE':
      return hdsMaterial.MaterialLevel.ADAPTIVE
    case 'SMOOTH':
      return hdsMaterial.MaterialLevel.SMOOTH
    case 'GENTLE':
      return hdsMaterial.MaterialLevel.GENTLE
    case 'EXQUISITE':
      return hdsMaterial.MaterialLevel.EXQUISITE
    default:
      return hdsMaterial.MaterialLevel.ADAPTIVE
  }
}

export function getHdsMaterialLevelRaw(level?: string): number {
  if (!level) {
    level = LocalValues.getInstance().getMaterialLevel()
  }

  console.log(`Material Level ${level}`)

  switch (level) {
    case 'ADAPTIVE':
      return 10
    case 'SMOOTH':
      return 2
    case 'GENTLE':
      return 1
    case 'EXQUISITE':
      return 0
    default:
      return 10
  }
}
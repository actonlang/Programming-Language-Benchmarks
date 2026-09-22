declare module '*.vue' {
  import V from 'vue'
  export default interface Vue extends V {}
}

type osType = 'linux' | 'osx' | 'windows'

type BenchmarkRun = {
  expectedLanguages: string[]
  publishedLanguages: string[]
  missingLanguages: string[]
  runnerName: string
  cpuInfo: string
  githubRepository: string
  githubRunId: string
  githubSha: string
}

type BenchResult = {
  cpuInfo: string
  lang: string
  os: osType
  compiler: string
  compilerVersion: string
  test: string
  input: string
  code: string
  status?: 'ok' | 'timeout'
  timeoutSeconds?: number
  timeMS: number | null
  timeStdDevMS: number | null
  memBytes: number | null
  cpuTimeMS: number | null
  cpuTimeUserMS: number | null
  cpuTimeKernelMS: number | null

  compilerOptions?: string

  par?: boolean
  timeout?: boolean

  // appveyorBuildId: string,
  githubRepository?: string
  githubSha?: string
  githubRunAttempt?: string
  runnerName?: string
  githubRunId: string
  buildLog: {
    compilerVersion: string
    start: string
    finished: string
    durationMs: number
  }
  testLog: {
    runtimeVersion: string
    start: string
    finished: string
    durationMs: number
  }
}

type LangBenchResults = {
  lang: string
  langDisplay: string
  benchmarks: BenchResult[]
}

type LangPageMeta = {
  lang?: string
  other?: string
  problem?: string
}

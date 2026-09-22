<template>
  <div
    class="text-gray-700 text-base subpixel-antialiased text-lg tracking-wide .leading-relaxed py-5 md:container md:mx-auto min-h-screen shadow-lg bg-gray-100 p-5"
  >
    <div class="bg-pink-800 text-white p-5 mb-5 text-3xl rounded">
      <a :href="$router.resolve('/').href"
        ><small class="text-lg">Programming Language and compiler</small> <br />
        Benchmarks</a
      >
    </div>
    <div v-if="benchmarkRun" class="bg-white p-4 mb-5 rounded text-base">
      <p>
        Results for {{ benchmarkRun.publishedLanguages.length }} of
        {{ benchmarkRun.expectedLanguages.length }} languages from
        <a :href="runUrl" class="underline text-blue-500">this run</a>
        on {{ benchmarkRun.runnerName }}.
      </p>
      <p v-if="benchmarkRun.missingLanguages.length" class="mt-2">
        Unavailable in this run:
        {{ benchmarkRun.missingLanguages.join(', ') }}. Follow the run link for
        failure details.
      </p>
    </div>
    <Nuxt />
  </div>
</template>

<script lang="ts">
import { Component, Vue } from 'nuxt-property-decorator'
@Component({
  components: {},
})
export default class DefaultLayout extends Vue {
  get benchmarkRun(): BenchmarkRun | null {
    return this.$config.benchmarkRun || null
  }

  get runUrl(): string {
    const run = this.benchmarkRun
    return run
      ? `https://github.com/${run.githubRepository}/actions/runs/${run.githubRunId}`
      : ''
  }
}
</script>

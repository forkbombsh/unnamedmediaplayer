const { execSync } = require("child_process");
const fs = require("fs");
const path = require("path");

// Paths
const folder = "./music";
const finalOutput = "merged_32.wav";
const tempFolder = "./temp_batches";
if (!fs.existsSync(tempFolder)) fs.mkdirSync(tempFolder);

// Load list.json
const list = JSON.parse(fs.readFileSync("list.json", "utf8"));

// Build ordered file paths based on list.json
const files = list.map(item => path.join(folder, item.audioFile));

// Batch size
const BATCH_SIZE = 50;

// Split into batches
const batches = [];
for (let i = 0; i < files.length; i += BATCH_SIZE) {
  batches.push(files.slice(i, i + BATCH_SIZE));
}

// Function to merge one batch
function mergeBatch(batchFiles, index) {
  const inputs = batchFiles.map(f => `-i "${f}"`).join(" ");
  const filter = batchFiles.map((_, i) => `[${i}:0]`).join("") + `concat=n=${batchFiles.length}:v=0:a=1[a]`;
  const outFile = path.join(tempFolder, `batch_${index}.wav`);
  const cmd = `ffmpeg ${inputs} -filter_complex "${filter}" -map "[a]" -ar 44100 -ac 2 -c:a pcm_s16le "${outFile}" -y`;
  console.log(`Merging batch ${index + 1}/${batches.length}...`);
  execSync(cmd, { stdio: "inherit" });
  return outFile;
}

// Merge all batches
const batchOutputs = batches.map((batch, i) => mergeBatch(batch, i));

// Merge batch outputs into final WAV
if (batchOutputs.length > 1) {
  const inputs = batchOutputs.map(f => `-i "${f}"`).join(" ");
  const filter = batchOutputs.map((_, i) => `[${i}:0]`).join("") + `concat=n=${batchOutputs.length}:v=0:a=1[a]`;
  const cmd = `ffmpeg ${inputs} -filter_complex "${filter}" -map "[a]" -ar 44100 -ac 2 -c:a pcm_s16le -f wav "${finalOutput}" -y`;
  console.log(`Merging final output into WAV...`);
  execSync(cmd, { stdio: "inherit" });
} else {
  // Single batch, just copy to final WAV
  const cmd = `ffmpeg -i "${batchOutputs[0]}" -c:a copy -f wav "${finalOutput}" -y`;
  execSync(cmd, { stdio: "inherit" });
}

execSync('ffmpeg -i merged_32.wav -c:a copy -f wav -rf64 auto merged.wav')
fs.unlinkSync("merged_32.wav");
console.log("Done!");

# Instant Jellyfin

This is a simple project designed to get you up and running with a Jellyfin server on AWS in a few simple clicks. This is also designed so that you can easily spin up, take down, and configure your jellyfin instance with as little coding as possible. Hopefully, after reading through all of this, and some of the code, you'll feel confident enough to customize this project to suit your own needs.

**A NOTE ON COSTS**: AWS can be pretty expensive, so with heavy usage and high definition, high bitrate content, you could incur heavy charges. I **highly** recommend doing some calculations and setting [billing alerts](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/monitor_estimated_charges_with_cloudwatch.html) before getting started. There are a few major components to cost with running Jellyfin on AWS:
* _S3 storage costs_: This is the cost to persistently store your media on S3.
* _EC2 running costs_: This is the actual cost to run your Jellyfin server instance.
* _EBS volume costs_: This is the cost of the hard drive space attached to your Jellyfin server instance. Movies are synced to this drive from S3 so Jellyfin can actually play the movies.
* _EC2 data transfer costs_: This is the cost of actually streaming data from your server to the internet, _separate_ from your server running costs. This can be significant if you have a lot of users streaming a lot of very high bitrate content.

## Getting Started

These instructions will walk you through the entire process of setting up a Jellyfin instance on AWS. It should be pretty easy to follow from top to bottom. If you run into any problems, please create an issue and let me know.

### Prerequisites

Forgive me, some of these are basic, but I list them here for less technical users.

1. You'll need to install docker and docker-compose to run this project. Please see https://docs.docker.com/install/ and https://docs.docker.com/compose/install/ for instructions on installing docker and docker compose on your system. Everything runs in docker containers to avoid any incompatibility issues with your system.
1. You'll need an AWS account with full administrator access. This guide assumes you're running this on your own personal AWS account, and that the AWS credentials you use have no restrictions. See https://aws.amazon.com/premiumsupport/knowledge-center/create-and-activate-aws-account/ for details on creating an AWS account.
1. You'll need your AWS access keys. See https://docs.aws.amazon.com/general/latest/gr/aws-sec-cred-types.html for details on getting those from the AWS console.
1. You'll need to know how to clone this project from Github. See https://help.github.com/en/github/creating-cloning-and-archiving-repositories/cloning-a-repository for details.
1. You'll need to know how to use a command line terminal. There are many tutorials out there for doing this, so I'll leave finding one for your system as an exercise for the reader.
1. I would recommend you sort out your encoding pipeline ahead of time to make sure you have videos in the appropriate format and bitrate for streaming via Jellyfin. I use Handbrake and the Nvidia NVEnc H.264 codec at 4000kbps for converting Blu-ray files from MakeMKV. I've included the handbrake preset file below for your convenience. Simply save as a `.json` file and import to Handbrake. Make sure to check your subtitle settings, since Handbrake doesn't seem to get them correct even with a preset.

```
{
  "PresetList": [
    {
      "AlignAVStart": true,
      "AudioCopyMask": [
        "copy:aac",
        "copy:ac3",
        "copy:dtshd",
        "copy:dts",
        "copy:mp3",
        "copy:truehd",
        "copy:flac",
        "copy:eac3"
      ],
      "AudioEncoderFallback": "av_aac",
      "AudioLanguageList": [
        "any"
      ],
      "AudioList": [
        {
          "AudioBitrate": 160,
          "AudioCompressionLevel": 0.0,
          "AudioEncoder": "av_aac",
          "AudioMixdown": "stereo",
          "AudioNormalizeMixLevel": false,
          "AudioSamplerate": "auto",
          "AudioTrackQualityEnable": false,
          "AudioTrackQuality": -1.0,
          "AudioTrackGainSlider": 0.0,
          "AudioTrackDRCSlider": 0.0
        }
      ],
      "AudioSecondaryEncoderMode": true,
      "AudioTrackSelectionBehavior": "all",
      "ChapterMarkers": true,
      "ChildrenArray": [],
      "Default": false,
      "FileFormat": "mp4",
      "Folder": false,
      "FolderOpen": false,
      "Mp4HttpOptimize": true,
      "Mp4iPodCompatible": false,
      "PictureAutoCrop": true,
      "PictureBottomCrop": 22,
      "PictureLeftCrop": 0,
      "PictureRightCrop": 0,
      "PictureTopCrop": 22,
      "PictureDARWidth": 1920,
      "PictureDeblockPreset": "off",
      "PictureDeblockTune": "medium",
      "PictureDeblockCustom": "strength=strong:thresh=20:blocksize=8",
      "PictureDeinterlaceFilter": "decomb",
      "PictureCombDetectPreset": "default",
      "PictureCombDetectCustom": "",
      "PictureDeinterlacePreset": "default",
      "PictureDeinterlaceCustom": "",
      "PictureDenoiseCustom": "",
      "PictureDenoiseFilter": "off",
      "PictureDenoisePreset": "light",
      "PictureDenoiseTune": "none",
      "PictureSharpenCustom": "",
      "PictureSharpenFilter": "off",
      "PictureSharpenPreset": "medium",
      "PictureSharpenTune": "none",
      "PictureDetelecine": "off",
      "PictureDetelecineCustom": "",
      "PictureItuPAR": false,
      "PictureKeepRatio": true,
      "PictureLooseCrop": false,
      "PictureModulus": 2,
      "PicturePAR": "auto",
      "PicturePARWidth": 1,
      "PicturePARHeight": 1,
      "PictureForceHeight": 0,
      "PictureForceWidth": 0,
      "PresetDescription": "Preset for HD Jellyfin streaming",
      "PresetName": "jellyfin-streaming",
      "Type": 1,
      "UsesPictureFilters": false,
      "UsesPictureSettings": 2,
      "SubtitleAddCC": true,
      "SubtitleAddForeignAudioSearch": false,
      "SubtitleAddForeignAudioSubtitle": false,
      "SubtitleBurnBehavior": "none",
      "SubtitleBurnBDSub": false,
      "SubtitleBurnDVDSub": false,
      "SubtitleLanguageList": [
        "any"
      ],
      "SubtitleTrackSelectionBehavior": "all",
      "VideoAvgBitrate": 4000,
      "VideoColorMatrixCode": 0,
      "VideoEncoder": "nvenc_h264",
      "VideoFramerateMode": "cfr",
      "VideoGrayScale": false,
      "VideoScaler": "swscale",
      "VideoPreset": "slow",
      "VideoTune": "",
      "VideoProfile": "auto",
      "VideoLevel": "auto",
      "VideoOptionExtra": "",
      "VideoQualityType": 1,
      "VideoQualitySlider": 22.0,
      "VideoQSVDecode": false,
      "VideoQSVAsyncDepth": 4,
      "VideoTwoPass": false,
      "VideoTurboTwoPass": false,
      "x264UseAdvancedOptions": false
    }
  ],
  "VersionMajor": 42,
  "VersionMicro": 0,
  "VersionMinor": 0
}
```

### Project Setup

1. Copy the `.env.template` file in the project root directory and name the copy `.env`. This is where your configuration for your Jellyfin instance will go, as well as the credentials you'll need to deploy. Below is a description of each item you'll need to configure. Inside your `.env` file, place the raw text string after the equals sign with no extra spaces.
	* `AWS_ACCESS_KEY_ID`: This is your access key ID from AWS. See _Prequisites_ for instructions on getting this.
	* `AWS_REGION`: This is the AWS region in which your Jellyfin instance will run. This should be close to where you'll be streaming the most from. See [this page](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.RegionsAndAvailabilityZones.html) for an overview of possible regions. You must use the lowercase-and-hyphen form of the region, e.g. `us-east-1`.
	* `AWS_SECRET_ACCESS_KEY`: This is your secret access key from AWS. See _Prequisites_ for instructions on getting this.
	* `EBS_MEDIA_VOLUME_SIZE`: This is the size of the drive that will be attached to the EC2 instance as a media storage drive, specified in gigabytes (GiB). Your media is syncronized to this drive, so it must be large enough to store everything you plan to upload. **WARNING**: Please make sure this is a different size than specified in `EBS_ROOT_VOLUME_SIZE`. Because of [the way AWS handles volume naming](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/device_naming.html), we use this unique volume size to detect the media volume and mount it as your `~/jellyfin/media` folder.
  * `EBS_MEDIA_VOLUME_TYPE`: This is the type of drive AWS will attach to your EC2 instance as the media volume. Valid values are `gp2`, `io1`, `st1`, and `sc1`. I'd recommend `st1` for large drives, and `gp2` for small drives. See https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-volume-types.html for a description of drive types.
  * `EBS_ROOT_VOLUME_SIZE`: This is the size of the drive that will be the root volume for your jellyfin instance, in gigabytes (GiB). It just needs enough space for working files. I'd recommend something on the order of `8`.
	* `EC2_INSTANCE_TYPE`: This is the type and size of the server you'll be running the Jellyfin instance on. See https://aws.amazon.com/ec2/instance-types/ for details on what types of instances are available. I would recommend something relatively small to start, especially if you're planning to primarily direct stream media instead of having Jellyfin transcode. The instance types should be of the form `type.size`, for instance `t3a.small`, which would make a good starting instance type. **WARNING**: This will affect your running cost significantly so make sure to calculate this ahead of time to avoid unwanted billing surprises.
	* `ENVIRONMENT`: This is an arbitrary name for your environment, to avoid conflicts if you decide to deploy multiple Jellyfin instances. I suggest a cool name, like _godzilla_.
	* `HOSTED_ZONE_ID`: (OPTIONAL) If you would like your Jellyfin instance to be available on a custom, nice and pretty domain, you will need fill this in. See _(Optional) Configuring DNS_ under the _Deployment_ section below for the steps to set this up.
	* `TERRAFORM_STATE_BUCKET`: This is an S3 bucket you will create that will store the configuration of your Terraform backend. Terraform is the tool that lets us write infrastructure as code and tell AWS what resources we need to create. Storing the infrastructure state in S3 ensures it doesn't get lost if something happens to your local machine.
1. Create an S3 bucket through the AWS console and set the `TERRAFORM_STATE_BUCKET` environment variable to the name of the bucket. Make sure you create this bucket in the region you specified in the `AWS_REGION` environment variable. Be sure to call it something unique, like _godzill-terraform-state_.
1. Create an ssh key by running `ssh-keygen -b 2048 -t rsa -f ./.ssh/jellyfin-key -q -P """"`. This will be used by our Terraform code to provision files on our EC2 instance.

Now you're all set and ready to start deploying!

## Deployment

The commands I'm going to list might seema a little complicated, but as long as you faithfully carry them out, you should be fine.

### (Optional) Configuring DNS

If you want your Jellyfin instance to be available at a particular domain name (let's say something cool, like `godzilla.pictures`), you should also complete these steps. This will host your Jellyfin instance at the apex (root) of your domain. Hosting on a different path on your domain requires customization of this project that will not be covered here.

1. Purchase a domain through Amazon Route53 in the AWS console. See https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/domain-register.html for details on how to do this.
	* You can, of course, use a domain purchased elsewhere and transfer that in to Route53, but I won't be covering that here.
1. Get the hosted zone ID of your domain. See https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/ListInfoOnHostedZone.html for details on how to do this. The hosted zone ID will be a random string of uppercase letters and numbers.
1. Fill in the `HOSTED_ZONE_ID` environment variable in your `.env` file with the hosted zone ID you got from the AWS console.
1. Proceed with the steps in _Deploying the Jellyfin instance_.

### Deploying the Jellyfin instance

1. Open a terminal and navigate to the project root directory.
1. Run `docker-compose -f docker-compose.terraform.init.yml up --build`
	* This will tell docker compose to run (`up`) the compose configuration in the init file (the file name after the `-f` flag), and to build (the `--build` flag) a fresh container to do so.
	* If docker compose prompts you for input when you run this, open a second terminal and run `docker attach instant-jellyfin_terraform_1`. You can then type into the second terminal and it will feed that input to the container running in the first terminal.
1. Run `docker-compose -f docker-compose.terraform.plan.yml up --build`
	* Exactly as above, this will run the plan file which will prompt terraform to create a plan to deploy your infrastructure. You can and should inspect this plan in the console to make sure you don't have any errors and everything looks correct.
1. If you're happy with the plan, run `docker-compose -f docker-compose.terraform.apply.yml up --build`
	* This applies the plan and deploys the infrastructure to AWS. It will also tell you if it runs into any errors.
	* Terraform also runs the initial setup steps via the provisioner blocks for the `jellyfin_server` resource in `jellyfin.tf`. The provisioners create any necessary files, install dependencies, start a `crontab` job to syncronize your media with S3 every few minutes, start the Jellyfin server, and start the Nginx reverse-proxy server to make Jellyfin available on the web.
1. Your Jellyfin instance should now be available at the domain name printed in the console.

## Configuring Jellyfin for the first time

1. Go to the domain name of your Jellyfin instance
1. Follow the on-screen instructions to set up your administrator account
	* There is no need to configure an SSL certificate, or any networking. This is taken care of be Terraform (it gets an SSL certificate from AWS and serves it with an Application Load Balancer).

## Uploading media
Now you can begin uploading media to S3 and it will automatically sync with your Jellyfin instance. Just follow the folder structure recommendations in the Jellyfin docs when uploading to S3. Your bucket should probably have a folders for `Movies`, `Shows`,`Music` and whatever else you want to serve with Jellyfin.

Once you've uploaded media into the folders as shown above, you should log in to Jellyfin and add a library connected to the folders. A script should be running on your server to automatically sync the `~/jellyfin/media` folder with S3 so, for instance, your `Movies` folder should be located under `~/jellyfin/media/Movies`.

## Managing your instance
If you need to manage your instance, such as restarting your docker container or manually messing around with files on your server, you should follow [AWS's instructions for connecting to your instance](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-connect-methods.html). I like use SSH in Ubuntu or Ubuntu through WSL (Windows Subsystem for Linux), but of course AWS provides a lovely browser-based SSH terminal as well. You must SSH into your instance using the EC2 instance domain generated by Amazon, not the domain your serve Jellyfin on your the load balancer domain.

The Terraform setup creates scripts on the server under the `~/jellyfin/scripts` set up the necessary services. There are a few scripts which Terraform creates,and they are all designed to be idempotent:
1. `~/jellyfin/scripts/s3sync.sh`: This script runs the S3 sync command, which ensures your local media folder exactly mirrors your S3 bucket. You can manually invoke this if you don't want to wait for the cron job. Be aware, if you delete something from S3 the sync command is set up to also delete it from the server.
1. `~/jellyfin/scripts/start-s3sync.sh`: This script adds a cron task to run `s3sync.sh` every five minutes. If you run it again, it will not add extra copies of the task, it will just re-create the task (check out the code in `jellyfin.tf` to see some wonderful code golf).
1. `~/jellyfin/scripts/start-jellyfin.sh`: This script checks whether the jellyfin docker container is running, kills and removes it if so, and then starts it again. Invoking it multiple times just restarts Jellyfin.
1. `~/jellyfin/scripts/start-nginx.sh`: This script starts the nginx reverse proxy if it's not already running, and restarts it if it is.
1. `~/jellyfin/scripts/start-backup.sh`: This script adds a cron task to run `backup.sh` every 6 hours. If you run it again, it will not add extra copies of the task, it will just re-create the task.
1. `~/jellyfin/scripts/backup.sh`: This backs up your Jellyfin configuration to S3. When you run it, it creates a folder on S3 named using the current date and time and syncs a backup `~/jellyfin/config` to the folder. S3 is configured by default to retain backups for 30 days.
1. `~/jellyfin/scripts/restore.sh`: This script restores a backup of your Jellyfin configuration from S3. You must pass it name of the folder in S3 which contains the backup you'd like to restore. For example, `/bin/bash ~/jellyfin/scripts/restore.sh "Fri Mar 27 00:00:01 UTC 2020"`

Terraform will run all of the `start-` scripts when the instance is first created, but feel free to run any of them via SSH.

If you ever need to re-create a specific part of the infrastructure, you can taint a resource by running `docker-compose -f docker-compose.terraform.plan.yml run terraform taint resource_type.resource_name` and then re-deploying. This will force the resource to be destroyed and re-created. Of course, substitute the resource type and name you want to re-create from the terraform code. For the EC2 instance itself, that would be `aws_instance.jellyfin_server`.

**DIRE WARNING**: If you decide to directly change your infrastructure through the AWS console, such as destroying your instance or fiddling about with settings like instance size (pretty much anything other than managing the instance through SSH and uploading media to S3), you could definitely cause your infrastructure to become out of sync with Terraform. THIS IS BAD. You do not want to be manually digging through your Terraform state trying to fix things. If you want to make an INFRASTRUCTURE change, do it through Terraform. Otherwise, make sure you know what you're doing.

## Destroying your instance

If you want to totally wipe out your infrastructure, you can do the following:

1. Delete everything from your media and backup S3 buckets. If you don't do this, Terraform will throw up and tell you that it can't delete a bucket which has things in it. This can be useful if you want to destroy everything _but_ your media and backup--you can run the destroy command and it will destroy everything but the S3 buckets which contain objects.
1. Open a terminal and navigate to the project root directory.
1. Run `docker-compose -f docker-compose.terraform.destroy.yml up --build`
	* This will ask you to confirm destruction. Open a second terminal and run `docker attach instant-jellyfin_terraform_1`. You can then type into the second terminal and it will feed that input to the container running in the first terminal.
	* This will really destroy everything, so be sure you want to proceed.

## Built With

* [Jellyfin](https://github.com/jellyfin/jellyfin) - The real deal, this is where the magic happens, my project is just to make setup on AWS easier.
* [Docker](https://www.docker.com/) Containers are great, this project uses docker containers.
* [Docker Compose](https://docs.docker.com/compose/) Docker compose is great, it's a very handy way to define and run Docker applications, especially those which need multiple containers running.
* [Terraform](https://www.terraform.io/) Terraform is a great, but sometimes scary tool. This is used to write infrastructure as code, and without it this whole project would be nearly impossible.

## Technical notes for those who care

* This Terraform setup is not the most secure it could be, in that it leaves SSH open to the public internet. This is for the sake of simplicity since I don't believe most of you are controlling NORAD from your Jellyfin server (I hope).
* This setup just uses `crontab` to run `aws s3 sync` every few minutes to update your media library from S3. Again, feel free to customize, and if you come up with a way more awesome solution please create a PR!
* This setup also uses `aws s3 sync` to back up your Jellyfin config every hour. This is a good stopgap for when you have to re-create your infrastructure, but if you come up with a better solution for backups, again, please create a PR!
* This project uses docker-compose to run Terraform commands inside a Terraform container to avoid having to deal with configuration issues on your local machine. Each docker-compose `.yml` file has a separate command and environment variable mapping. I like this setup because it's easy to use, easy to version, and easy to modify. If you don't like this, I'm always open to suggestions.
* For simplicity, the paths in the setup and start scripts are absolute paths and cannot be configured. If you need to run jellyfin and the associated services from different folders, feel free to configure the terraform code as you like, or upgrade it to support configurable folder paths.
* You'll notice that I run `dos2unix` on the scripts that Terraform creates. This is because I've been developing this on both Windows and Linux, and discovered that on Windows, Terraform created files with Windows line endings, causing the scripts to fail in really weird ways. The better solution is probably to not use provisioners like this, but it works well for a small project like this.

## Contributing

If you would like to contribute, open a PR, or an issue, or just message me.

## Versioning

We use [SemVer](http://semver.org/) for versioning. For the versions available, see the [tags on this repository](https://github.com/your/project/tags). 

## Authors

* **Joey Triska**

See also the list of [contributors](https://github.com/your/project/contributors) who participated in this project.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.MD) file for details

## Acknowledgments

* Thanks to the folks who build Jellyfin, because it's pretty great so far.
* Thanks to the folks that build Docker and Terraform, too, because those are great tools to have in your toolbox.

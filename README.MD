# Instant Jellyfin

This is a simple project designed to get you up and running with a Jellyfin server on AWS in a few simple clicks. This is also designed so that you can easily spin up, take down, and configure your jellyfin instance with as little coding as possible. Hopefully, after reading through all of this, and some of the code, you'll feel confident enough to customize this project to suit your own needs.

## DISCLAIMER
I provide absolutely no warranties for this code or documentation, and am not responsible for the security, cost, or any other aspect your infrastructure, code, or applications. I make absolutely no claims or warranties about your ability to legally copy or serve any video content. I also am not part of the Jellyfin project and cannot provide information, guidance, or warranties on their behalf. Please exercise your own judgement.

## Getting Started

These instructions will walk you through the entire process of setting up a Jellyfin instance on AWS. It should be pretty easy to follow from top to bottom. If you run into any problems, please create an issue and let me know.

### Prerequisites

1. You'll need to install docker and docker-compose to run this project. Please see https://docs.docker.com/install/ and https://docs.docker.com/compose/install/ for instructions on installing docker and docker compose on your system. Everything runs in docker containers to avoid any incompatibility issues with your system.
1. You'll need an AWS account with full administrator access. This guide assumes you're running this on your own personal AWS account, and that the AWS credentials you use have no restrictions. See https://aws.amazon.com/premiumsupport/knowledge-center/create-and-activate-aws-account/ for details on creating an AWS account.
1. You'll need your AWS access keys. See https://docs.aws.amazon.com/general/latest/gr/aws-sec-cred-types.html for details on getting those from the AWS console.
1. You'll need to know how to clone this project from Github. See https://help.github.com/en/github/creating-cloning-and-archiving-repositories/cloning-a-repository for details.
1. You'll need to know how to use a command line terminal. There are many tutorials out there for doing this, so I'll leave finding one for your system as an exercise for the reader.
1. I would highly recommend you sort out your encoding pipeline ahead of time to make sure you have videos in the appropriate format and bitrate for streaming via Jellyfin. I use Handbrake and the Nvidia NVEnc H.264 codec for converting Blu-ray files from MakeMKV. I've included a handbrake preset for your convenience (see the included `jellyfin-handbrake.json`), although you should especially check the subtitle conversion when you run a transcode.

### Project Setup

1. Copy the `.env.template` file in the project root directory and name the copy `.env`. This is where your configuration for your Jellyfin instance will go, as well as the credentials you'll need to deploy. Below is a description of each item you'll need to configure. Inside your `.env` file, place the raw text string after the equals sign with no extra spaces.
	* `AWS_ACCESS_KEY_ID`: This is your access key ID from AWS. See _Prequisites_ for instructions on getting this.
	* `AWS_REGION`: This is the AWS region in which your Jellyfin instance will run. This should be close to where you'll be streaming the most from. See [this page](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.RegionsAndAvailabilityZones.html) for an overview of possible regions. You must use the lowercase-and-hyphen form of the region, e.g. `us-east-1`.
	* `AWS_SECRET_ACCESS_KEY`: This is your secret access key from AWS. See _Prequisites_ for instructions on getting this.
	* `EBS_VOLUME_SIZE`: 
	* `EC2_INSTANCE_TYPE`: This is the type and size of the server you'll be running the Jellyfin instance on. See https://aws.amazon.com/ec2/instance-types/ for details on what types of instances are available. I would recommend something relatively small to start, especially if you're planning to primarily direct stream media instead of having Jellyfin transcode. The instance types should be of the form `type.size`, for instance, a `t3a.small` would make a good starting instance type.
	* `ENVIRONMENT`: This is an arbitrary name for your environment, to avoid conflicts if you decide to deploy multiple Jellyfin instances. I suggest a cool name, like _godzilla_.
	* `HOSTED_ZONE_ID`: (OPTIONAL) If you would like your Jellyfin instance to be available on a custom, nice and pretty domain, you will fill this in. See _(Optional) Configuring DNS_ under the _Deployment_ section below for the steps to do this.
	* `TERRAFORM_STATE_BUCKET`: This is an S3 bucket you will create that will store the configuration of your Terraform backend. Terraform is the tool that lets us write infrastructure like code and tell AWS what resources we need to create. You'll definitely want to use a remote backend like S3 so you don't lose track of your infrastructure state if something happens to your local computer.
1. Create an S3 bucket through the AWS console and set the `TERRAFORM_STATE_BUCKET` environment variable to the name of the bucket. So if you call your S3 bucket `godzilla-jellyfin-backend`, that's exactly what you should put. Make sure you create this bucket in the region you specified in the `AWS_REGION` environment variable. I'd also recommend adding the

Now you're all set and ready to start deploying!

## Deployment

The commands I'm going to list might seema a little complicated, but as long as you faithfully carry them out, you should be fine.

### (Optional) Configuring DNS

If you want your Jellyfin instance to be available at a particular domain name (let's say something cool, like `godzilla.pictures`), you should also complete these steps. This will host your Jellyfin instance at the root of your domain. Hosting on a different path on your domain requires customization of this project that will not be covered here.

1. Purchase a domain through Amazon Route53 in the AWS console. See https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/domain-register.html for details on how to do this.
	* You can, of course, use a domain purchased elsewhere and transfer that in to Route53, but I won't be covering that here.
1. Get the hosted zone ID of your domain. See https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/ListInfoOnHostedZone.html for details on how to do this. The hosted zone ID will be a random string of uppercase letters and numbers.
1. Fill in the `HOSTED_ZONE_ID` environment variable in your `.env` file with the hosted zone ID you got from the AWS console.
1. Proceed with the steps in _Deploying the Jellyfin instance_.

### Deploying the Jellyfin instance

1. Open a terminal and navigate to the project root directory.
1. Run `docker-compose -f docker-compose.terraform.init.yml up --build`
	* This will tell docker compose to run (`up`) the compose configuration in the init file (the file name after the `-f` flag), and to build (the `--build` flag) a fresh container to do so.
	* If docker compose prompts you for input when you run this, open a second terminal and run `docker attach jellyfin_terraform_1`. You can then type into the second terminal and it will feed that input to the container running in the first terminal.
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

Once you've uploaded media into the folders as shown above, you should log in to Jellyfin and add a library connected to the folders. A script should be running on your server to automatically sync the `/jellyfin/media` folder with S3 so, for instance, your `Movies` folder should be located under `/jellyfin/media/Movies`.

## Managing your instance
If you need to manage your instance, such as restarting your docker container or manually messing around with files on your server, you should follow [AWS's instructions for connecting to your instance](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-connect-methods.html). I like use SSH in Ubuntu or Ubuntu through WSL (Windows Subsystem for Linux), but of course AWS provides a lovely browser-based SSH terminal as well.

The Terraform setup creates scripts on the server under the `/jellyfin/scripts` folder to set up dependencies on the EC2 instance and start the necessary services. You can manually start, stop, or re-run these as necessary through SSH. The scripts are designed to be idempotent, that is, they're designed so that they won't break anything if you run them multiple times. The start scripts will fully restart the associated services if you run them again.

If you need to totally destroy and re-create your Jellyfin instance to start over, you can use terraform taint, then re-run the deploy steps. You can taint a resource by running `docker-compose -f docker-compose.terraform.plan.yml run terraform taint resource_type.resource_name`, which will force it to be destroyed and re-created. Of course, substitute the resource type and name you want to re-create from the terraform code. For the EC2 instance, that would be `aws_instance.jellyfin_server`.

You can also, of course, run the Terraform destroy command if you want to completely wipe out your infrastructure, but you'll have to manually empty your s3 bucket first, and of course re-upload all of your media.

**DIRE WARNING**: If you decide to directly change your infrastructure through the AWS console, such as destroying your instance or fiddling about with settings like instance size (pretty much anything other than managing the instance through SSH and uploading media to S3), you could definitely cause your infrastructure to become out of sync with Terraform. THIS IS BAD. You do not want to be manually digging through your Terraform state trying to fix things. If you want to make an INFRASTRUCTURE change, do it through Terraform. Otherwise, make sure you know what you're doing.

## Destroying your instance

If you want to totally wipe out your infrastructure, you can do the following:

1. Delete everything from your media S3 bucket. If you don't do this, Terraform will throw up and tell you that it can't delete a bucket which has things in it.
1. Open a terminal and navigate to the project root directory.
1. Run `docker-compose -f docker-compose.terraform.destroy.yml up --build`
	* This will ask you to confirm destruction. Open a second terminal and run `docker attach jellyfin_terraform_1`. You can then type into the second terminal and it will feed that input to the container running in the first terminal.
	* This will really destroy everything, so be sure you want to proceed.

## Built With

* [Jellyfin](https://github.com/jellyfin/jellyfin) - The real deal, this is where the magic happens, my project is just to make setup on AWS easier.
* [Docker](https://www.docker.com/) Containers are great, this project uses docker containers.
* [Docker Compose](https://docs.docker.com/compose/) Docker compose is great, it's a very handy way to define and run Docker applications, especially those which need multiple containers running.
* [Terraform](https://www.terraform.io/) Terraform is a great, but sometimes scary tool. This is used to write infrastructure as code, and without it this whole project would be nearly impossible.

## Technical notes for those who care

* This terraform setup doesn't isolate everything in a purpose-built VPC, it just dumps everything in the default VPC. If you understand this, you probably understand how to add that to the Terraform code.
* This setup also leaves your SSH port open on the server so it's easier to configure. If you are not happy with that, it's easy to change in the Terraform.
* This setup just uses `crontab` to run `aws s3 sync` every 5 minutes to update your media library from S3. Again, feel free to customize and if you come up with a way more awesome solution, please create a PR!
* This project uses docker-compose to run Terraform commands inside a Terraform container to avoid having to deal with configuration issues on your local machine. Each docker-compose `.yml` file has a separate command and environment variable mapping. I like this setup because it's easy to use, easy to version, and easy to modify. If you don't like this, I'm always open to suggestions.
* For simplicity, the paths in the setup and start scripts are absolute paths and cannot be configured. If you need to run jellyfin and the associated services from different folders, feel free to configure the terraform code as you like, or upgrade it to support configurable folder paths.
* This project doesn't support having a separate EBS volume to stage media. It would be a nice-to-have, but too time consuming right now. Again, this would be a neat area for someone to take a look at (or better yet, get mo)

## Contributing

If you would like to contribute, open a PR, or an issue, or just message me.

## Versioning

We use [SemVer](http://semver.org/) for versioning. For the versions available, see the [tags on this repository](https://github.com/your/project/tags). 

## Authors

* **Joey Triska**

See also the list of [contributors](https://github.com/your/project/contributors) who participated in this project.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details

## Acknowledgments

* Thanks to the folks who build Jellyfin, because it's pretty great so far.
* Thanks to the folks that build Docker and Terraform, too, because those are great tools to have in your toolbox.
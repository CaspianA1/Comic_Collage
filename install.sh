/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
brew install python
pip3 install pillow || pip install pillow
echo "alias generator_app=\"python3 Desktop/Collage_Generator/calvin_collage_maker.command || python Desktop/Collage_Generator/calvin_collage_maker.command\"" >> ~/.bashrc
chmod +x calvin_collage_maker.command

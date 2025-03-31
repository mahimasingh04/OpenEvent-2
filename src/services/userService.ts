
import { toast } from "sonner";

export interface UserProfile {
  address: string;
  name?: string;
  bio?: string;
  skills: string[];
  pastEvents: PastEvent[];
  avatar?: string;
  joinedDate: Date;
}

export interface PastEvent {
  id: string;
  name: string;
  date: string;
  role: string;
  achievement?: string;
}

export interface Badge{
  id : string,
  name :  string,
  description: string,
  imageURL : string,
  criteria : string,
  isAchieved : boolean,
  dateAchieved : Date,
  eventId: string,
  eventName : string,
  
}
// Mock storage for user profiles
const userProfiles: Record<string, UserProfile> = {};

export const getUserProfile = async (address: string): Promise<UserProfile | null> => {
  try {
    // First check if we have the profile in our mock storage
    if (userProfiles[address.toLowerCase()]) {
      return userProfiles[address.toLowerCase()];
    }
    
    // If not, create a new profile with default values
    const newProfile: UserProfile = {
      address,
      skills: [],
      pastEvents: [],
      joinedDate: new Date()
    };
    
    userProfiles[address.toLowerCase()] = newProfile;
    return newProfile;
  } catch (error) {
    console.error('Error getting user profile:', error);
    return null;
  }
};

export const updateUserProfile = async (
  address: string, 
  profileData: Partial<UserProfile>
): Promise<UserProfile | null> => {
  try {
    // Get existing profile or create new one
    const existingProfile = await getUserProfile(address);
    
    if (!existingProfile) {
      throw new Error('Failed to get user profile');
    }
    
    // Update profile with new data
    const updatedProfile: UserProfile = {
      ...existingProfile,
      ...profileData,
      // Make sure address and joinedDate are preserved
      address: existingProfile.address,
      joinedDate: existingProfile.joinedDate
    };
    
    // Save to mock storage
    userProfiles[address.toLowerCase()] = updatedProfile;
    
    toast.success("Profile updated successfully");
    return updatedProfile;
  } catch (error) {
    console.error('Error updating user profile:', error);
    toast.error("Failed to update profile");
    return null;
  }
};

export const addUserSkill = async (
  address: string, 
  skill: string
): Promise<UserProfile | null> => {
  try {
    const profile = await getUserProfile(address);
    
    if (!profile) {
      throw new Error('Failed to get user profile');
    }
    
    // Check if skill already exists
    if (profile.skills.includes(skill)) {
      toast.error("This skill already exists in your profile");
      return profile;
    }
    
    // Add new skill
    const updatedProfile = {
      ...profile,
      skills: [...profile.skills, skill]
    };
    
    // Save to mock storage
    userProfiles[address.toLowerCase()] = updatedProfile;
    
    toast.success("Skill added successfully");
    return updatedProfile;
  } catch (error) {
    console.error('Error adding skill:', error);
    toast.error("Failed to add skill");
    return null;
  }
};

export const removeUserSkill = async (
  address: string, 
  skill: string
): Promise<UserProfile | null> => {
  try {
    const profile = await getUserProfile(address);
    
    if (!profile) {
      throw new Error('Failed to get user profile');
    }
    
    // Remove skill
    const updatedProfile = {
      ...profile,
      skills: profile.skills.filter(s => s !== skill)
    };
    
    // Save to mock storage
    userProfiles[address.toLowerCase()] = updatedProfile;
    
    toast.success("Skill removed successfully");
    return updatedProfile;
  } catch (error) {
    console.error('Error removing skill:', error);
    toast.error("Failed to remove skill");
    return null;
  }
};

export const addPastEvent = async (
  address: string, 
  event: PastEvent
): Promise<UserProfile | null> => {
  try {
    const profile = await getUserProfile(address);
    
    if (!profile) {
      throw new Error('Failed to get user profile');
    }
    
    // Add event
    const updatedProfile = {
      ...profile,
      pastEvents: [...profile.pastEvents, event]
    };
    
    // Save to mock storage
    userProfiles[address.toLowerCase()] = updatedProfile;
    
    toast.success("Event added to your profile");
    return updatedProfile;
  } catch (error) {
    console.error('Error adding event:', error);
    toast.error("Failed to add event to your profile");
    return null;
  }
};

export const removePastEvent = async (
  address: string, 
  eventId: string
): Promise<UserProfile | null> => {
  try {
    const profile = await getUserProfile(address);
    
    if (!profile) {
      throw new Error('Failed to get user profile');
    }
    
    // Remove event
    const updatedProfile = {
      ...profile,
      pastEvents: profile.pastEvents.filter(e => e.id !== eventId)
    };
    
    // Save to mock storage
    userProfiles[address.toLowerCase()] = updatedProfile;
    
    toast.success("Event removed from your profile");
    return updatedProfile;
  } catch (error) {
    console.error('Error removing event:', error);
    toast.error("Failed to remove event from your profile");
    return null;
  }
};
